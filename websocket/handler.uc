/* Copyright (C) 2024 John Crispin <john@phrozen.org> */

'use strict';

import { ulog_open, ulog, ULOG_SYSLOG, ULOG_STDIO, LOG_DAEMON, LOG_INFO } from 'log';
import * as users from 'uconfig.websocket.users';
import * as datamodel from 'cli.datamodel';
import { readfile, writefile } from 'fs';
import { generate } from 'wizard';
import * as libubus from 'ubus';
import { timer } from 'uloop';

let ubus = libubus.connect();

ulog_open(ULOG_SYSLOG | ULOG_STDIO, LOG_DAEMON, 'uconfig.server');

global.connections = {};
global.uconfig_webui = true;
global.shutdown = false;

let settings = json(readfile('/etc/uconfig/webui.json') || '{}');

function send(connection, data, no_log) {
	let peer = connection?.info()?.peer_address;
	if (!peer)
		return;
	if (!no_log)
		warn(`${peer}: TX ${data}\n`);
	connection.send(`${data}`);
}

function broadcast(data, no_log) {
	for (let name, connection in global.connections)
		send(connection, data, no_log);
}

let ping_timer;
function ping() {
	broadcast([ 'ping' ], true);
	ping_timer.set(5000);
}
ping_timer = timer(1000, ping);

let model = datamodel.new({
	status_msg: (msg) => { 
		broadcast([ 'event', msg ]);
	},
});
model.add_modules();
model.init();

function connect_cb(connection) {
	try {
		let event = 'login-required';

		if (connection.data()?.authenticate)
			event = 'authenticated';
		if (!settings.configured)
			event = 'setup-required';

		send(connection, [ event ]);
	} catch(e) {
		warn(`${e.stacktrace[0].context}\n`);
		return;
	}
}

function connection_name(connection) {
	let info = connection.info();

	return `${info.peer_address}:${info.peer_port}`;
}

export function onConnect(connection, protocols)
{
	if (global.shutdown)
		return connection.close(1012, 'Server is restarting');

	if (!('config' in protocols))
		return connection.close(1003, 'Unsupported protocol requested');
 
	let cli = model.context();
	cli = cli.select([ 'uconfig' ]);

	connection.data({
		counter: 0,
		n_messages: 0,
		n_fragments: 0,
		msg: '',
		cli,
	});

        let name = connection_name(connection);
	global.connections[name] = connection;

	ulog(LOG_INFO, name + ' connected\n');
	timer(1000, () => connect_cb(connection));

	return connection.accept('config');
};

export function onClose(connection, code, reason)
{
        let name = connection_name(connection);
	ulog(LOG_INFO, name + ' disconnected\n');
        if (global.connections[name].cli)
		delete global.connections[name].cli;
        delete global.connections[name];
};

let states = {
	system: function(connection) {
		return {
			board: ubus.call('system', 'board'),
			info: ubus.call('system', 'info'),
		};
	},

	fingerprint: function(connection) {
		return ubus.call('fingerprint', 'fingerprint');
	},
};

let handlers = {
	authenticate: function(connection, data) {
		if (connection?.data()?.authenticate) {
			send(connection, [ 'authenticated', { pendig_changes: !!model.uconfig.changed }]);
			return;
		}

		if (length(data) != 2 ||
		    !users.login(data[0], data[1])) {
			send(connection, [ 'wrong-password' ]);
			return;
		}

		ulog(LOG_INFO, `${data[0]} logged in \n`);
		connection.data().authenticated = true;
		send(connection, [ 'authenticated', { pendig_changes: !!model.uconfig.changed } ]);
	},

	password: function(connection, data) {
		if (length(data) < 2)
			return;
		let id = shift(data); 
		let ret = users.passwd(data[0]);
		send(connection, [ 'result', id, !!ret ]);
	},

	command: function(connection, data, cli) {
		if (length(data) < 2)
			return;
		let id = shift(data); 
		let ret = cli.call(data);
		send(connection, [ 'result', id, ret ]);
	},

	get: function(connection, data, cli) {
		if (length(data) < 2)
			return;

		let id = shift(data); 
		let ret = { };
		for (let name, path in data[0]) {
			let data = cli.call(path);
			ret[name] = data.data;
		}
		send(connection, [ 'result', id, ret ]);
	},

	set: function(connection, data, cli) {
		if (length(data) < 2)
			return;

		cli.call([ 'push' ]);

		let id = shift(data); 
		let ret = {
			errors: [],
			ok: true
		};
		
		for (let name, path in data[0]) {
			let data = cli.call(path);
			if (!data.ok) {
				ret.ok = false;
				ret.errors = [ ...ret.errors, ...data.errors ];
			}
		}
		if (!ret.ok)
			cli.call([ 'pop' ]);
		send(connection, [ 'result', id, ret ]);
	},

	action: function(connection, data) {
		switch(data[0]) {
		case 'reboot':
			global.shutdown = true;
			system('reboot');
			break;
		}
	},

	state: function(connection, data) {
		if (length(data) < 2)
			return;
		let id = shift(data);
		let ret = { ok: false };
		if (states[data[0]]) {
			ret.data = states[data[0]](data);
			ret.ok = true;
		}
		send(connection, [ 'result', id, ret ]);
	},

	'setup-wizard': function(connection, data, cli) {
		ulog(LOG_INFO, `${data[0]} completed setup wizard\n`);
		
		settings.configured = true;
		settings.mode = data[0].mode;

		writefile('/etc/uconfig/webui.json', settings);
		generate(data[0]);

		connection.data().authenticated = true;
		send(connection, [ 'authenticated', { pendig_changes: !!model.uconfig.changed } ]);
		cli.call([ 'reset' ]);
	}
};

export function onData(connection, data, final)
{
	if (global.shutdown)
		return connection.close(1012, 'Server is restarting');

	let ctx = connection.data();

	if (!ctx)
		return connection.close(1009, 'Message too big');

	if (length(ctx.msg) + length(data) > 32 * 1024)
		return connection.close(1009, 'Message too big');

	ctx.msg = ctx.n_fragments ? ctx.msg + data : data;
	if (final) {
		ctx.n_messages++;
		ctx.n_fragments = 0;
	} else {
		ctx.n_fragments++;
		return;
	}

	try {
		let msg = json(data);
		if (msg) {
			warn(`${connection.info().peer_address}: RX ${msg}\n`);

			let handler = shift(msg);
			if (!settings.configured) {
				if (handler != 'setup-wizard') {
					send(connection, [ 'setup-required' ]);
					return;
				}
			} else if (!connection.data().authenticated) {
				if (handler != 'authenticate') {
					send(connection, [ 'login-required' ]);
					return;
				}
			}

			if (handlers[handler])
				handlers[handler](connection, msg, connection.data().cli)
		}

	} catch(e) {
		warn(`${e.stacktrace[0].context}\n`);
		return;
	}
};

export function onRequest(request, method, uri) {
//	return upload.onRequest(request, method, uri);
};

export function onBody(request, data) {
//	return upload.onBody(request, data);
};
