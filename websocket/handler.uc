/* Copyright (C) 2024 John Crispin <john@phrozen.org> */

'use strict';

import { ulog_open, ulog, ULOG_SYSLOG, ULOG_STDIO, LOG_DAEMON, LOG_INFO } from 'log';
import * as users from 'uconfig.websocket.users';
import * as datamodel from "cli.datamodel";
import { timer } from 'uloop';

ulog_open(ULOG_SYSLOG | ULOG_STDIO, LOG_DAEMON, 'uconfig.server');

global.connections = {};
global.uconfig_webui = true;

function send(connection, data) {
	warn(`${connection.info().peer_address}: TX ${data}\n`);
	connection.send(`${data}`);
}

function broadcast(data) {
	for (let name, connection in global.connections)
		send(connection, data);
}

let model = datamodel.new({
	status_msg: (msg) => { 
		broadcast([ 'event', msg ]);
	},
});
model.add_modules();
let event = model.context();
model.init();
event.select([ 'uconfig' ]);
event.call([ 'event', 'subscribe' ]);

function connect_cb(connection) {
	try {
		let event = 'login-required';

		if (connection.data().username)
			event = 'authenticated';

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
 
	let model = datamodel.new({
		status_msg: (msg) => { },
	});
	model.add_modules();
	let cli = model.context();
	model.init();
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
        delete global.connections[name];
};

let handlers = {
	authenticate: function(connection, cli, data) {
		if (connection.data().username) {
			send(connection, [ 'authenticated' ]);
			return;
		}

		if (length(data) != 2 ||
		    !users.login(data[0], data[1])) {
			send(connection, [ 'login-required' ]);
			return;
		}

		ulog(LOG_INFO, `${data[0]} logged in \n`);
		connection.data().username = data[0];
		send(connection, [ 'authenticated' ]);
	},

	password: function(connection, cli, data) {
		if (length(data) < 2)
			return;
		let id = shift(data); 
		let ret = users.passwd(data[0]);
		send(connection, [ 'result', id, !!ret ]);
	},

	command: function(connection, cli, data) {
		if (length(data) < 2)
			return;
		let id = shift(data); 
		let ret = cli.call(data);
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
			if (handler != 'authenticate' && !connection.data().username) {
				send(connection, [ 'login-required' ]);
				return;
			}

			if (handlers[handler])
				handlers[handler](connection, connection.data().cli, msg)
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
