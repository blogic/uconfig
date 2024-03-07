/* Copyright (C) 2024 John Crispin <john@phrozen.org> */

'use strict';

import { ulog_open, ulog, ULOG_SYSLOG, ULOG_STDIO, LOG_DAEMON, LOG_INFO } from 'log';
import * as credentials from 'credentials';
import * as datamodel from 'cli.datamodel';
import { readfile, writefile } from 'fs';
import { generate } from 'wizard';
import { devices } from 'devices';
import * as users from 'users';
import { ubus } from 'libubus';
import * as state from 'state';
import { timer } from 'uloop';

ulog_open(ULOG_SYSLOG | ULOG_STDIO, LOG_DAEMON, 'uconfig.server');

global.connections = {};
global.uconfig_webui = true;
global.shutdown = false;

global.settings = json(readfile('/etc/uconfig/webui.json') || '{}');

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

function shutdown() {
	global.shutdown = true;
	for (let name, connection in global.connections)
		connection.close(1012, 'Server is restarting');
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
		if (!global.settings.configured)
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

	devices: function(connection, data, cli) {
		return devices(cli);
	},

	internet: function() {
		return state.internet();
	},
};

let user = {
	list: function() {
		return users.list();
	},

	password: function(connection, data) {
		return users.set_password(data)
	},
};

let actions = {
	reboot: function() {
		shutdown();
		timer(2000, () => {
			ulog(LOG_INFO, 'rebooting\n');
			ubus.call('system', 'reboot')
		});
	},

	factory: function() {
		shutdown();
		timer(2000, () => {
			ulog(LOG_INFO, 'factory resetting\n');
			system('factoryreset -y -r');
		});
	},


};

let handlers = {
	authenticate: function(connection, data) {
		if (connection?.data()?.authenticate) {
			send(connection, [ 'authenticated', { pending_changes: !!model.uconfig.changed, mode: global.settings.mode }]);
			return;
		}

		if (length(data) != 2 ||
		    !credentials.login(data[0], data[1])) {
			send(connection, [ 'wrong-password' ]);
			return;
		}

		ulog(LOG_INFO, `${data[0]} logged in \n`);
		connection.data().authenticated = true;
		send(connection, [ 'authenticated', { pendig_changes: !!model.uconfig.changed, mode: global.settings.mode } ]);
	},

	password: function(connection, data) {
		if (length(data) < 2)
			return;
		let id = shift(data); 
		credentials.passwd('admin', data[0]);
		send(connection, [ 'result', id, true ]);
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
			if (!data?.ok) {
				ret.ok = false;
				ret.errors = [ ...ret.errors, ...data?.errors ];
			}
		}
		if (!ret.ok)
			cli.call([ 'pop' ]);
		send(connection, [ 'result', id, ret ]);
	},

	action: function(connection, data) {
		if (!actions[data[0]])
			return;
		actions[data[0]]();
	},

	state: function(connection, data, cli) {
		if (length(data) < 2)
			return;
		let id = shift(data);
		let ret = { ok: false };
		if (states[data[0]]) {
			ret.data = states[data[0]](connection, data, cli);
			ret.ok = true;
		}
		send(connection, [ 'result', id, ret ]);
	},

	user: function(connection, data, cli) {
		if (length(data) < 2)
			return;
		let id = shift(data);
		let cmd = shift(data);
		let ret = { ok: false };
		if (user[cmd]) {
			ret.data = user[cmd](connection, data, cli);
			ret.ok = !!ret.data;
		}
		send(connection, [ 'result', id, ret ]);
	},

	'setup-wizard': function(connection, data, cli) {
		ulog(LOG_INFO, `${data[0]} completed setup wizard\n`);
		
		global.settings.configured = true;
		global.settings.mode = data[0].mode;

		writefile('/etc/uconfig/webui.json', global.settings);
		generate(data[0]);

		cli.call([ 'reset' ]);
		
		connection.data().authenticated = true;
		send(connection, [ 'authenticated', { pending_changes: !!model.uconfig.changed, mode: global.settings.mode }]);
	},

	'firmware-check': function(connection, data) {
		if (!length(data))
			return;
		let id = shift(data); 

		let ret = { ok: true, data: {}};
		if (!system('/usr/sbin/uconfig-upgrade check'))
			ret.data = json(readfile('/tmp/upgrade.json'));
		send(connection, [ 'result', id, ret ]);
	},

	'firmware-download': function(connection, data) {
		if (!length(data))
			return;
		let id = shift(data); 

		let ret = { ok: true, data: { confirmed: false }};
		if (!system('/usr/sbin/uconfig-upgrade download'))
			ret.data.confirmed = true;
		send(connection, [ 'result', id, ret ]);
	},
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
			if (!global.settings.configured) {
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
