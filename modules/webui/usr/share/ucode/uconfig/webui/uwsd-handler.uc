'use strict';

import {
	ERROR_METHOD_NOT_FOUND,
	ERROR_INVALID_PARAMS,
	ERROR_INTERNAL,
	ERROR_LOGIN_REQUIRED,
	ERROR_INVALID_PASSWORD,
	parse_request,
	response_success,
	response_error
} from 'uconfig.webui.uwsd.jsonrpc';

import { login, change_password } from 'uconfig.webui.uwsd.auth';
import { register as register_ucoord } from 'uconfig.webui.uwsd.ucoord';
import { register as register_local } from 'uconfig.webui.uwsd.local';
import * as ubus from 'ubus';
import * as uloop from 'uloop';

global.connections = {};
global.shutdown = false;

function send_response(connection, response) {
	let data = sprintf('%.J', response);
	connection.send(data);
}

function send_event(connection, event_name, params) {
	let event = {
		jsonrpc: '2.0',
		method: event_name
	};
	if (params)
		event.params = params;
	let data = sprintf('%.J', event);
	connection.send(data);
}

function broadcast_event(event_name, params) {
	for (let name, conn in global.connections)
		send_event(conn, event_name, params);
}

function connection_name(connection) {
	let info = connection.info();
	return `${info.peer_address}:${info.peer_port}`;
}

function ucoord_present() {
	let objects = ubus.list();
	return objects && index(objects, 'ucoord') >= 0;
}

const mode = ucoord_present() ? 'ucoord' : 'standalone';

function handle_ping(connection, id, params) {
	send_response(connection, response_success(id, { success: true }));
}

function handle_login(connection, id, params) {
	if (type(params) != 'object' || !params.password)
		return send_response(connection, response_error(id, ERROR_INVALID_PARAMS, 'Invalid params'));

	let result = login(params.password);
	if (!result)
		return send_response(connection, response_error(id, ERROR_INVALID_PASSWORD, 'Invalid password'));

	connection.data().authenticated = true;
	send_response(connection, response_success(id, { ...result, mode }));
}

function handle_logout(connection, id, params) {
	connection.data().authenticated = false;
	send_response(connection, response_success(id, { success: true }));
}

function handle_change_password(connection, id, params) {
	if (type(params) != 'object' || !params.password)
		return send_response(connection, response_error(id, ERROR_INVALID_PARAMS, 'Invalid params'));

	let result = change_password(params.password);
	if (result.error)
		return send_response(connection, response_error(id, ERROR_INVALID_PARAMS, 'Invalid params', { reason: result.error }));

	send_response(connection, response_success(id, result));
}

function handle_devices(connection, id, params) {
	let devices = ubus.call('state', 'devices', { arp: true });

	if (!devices)
		return send_response(connection, response_error(id, ERROR_INTERNAL, 'Failed to retrieve device information'));

	send_response(connection, response_success(id, devices));
}

function handle_traffic(connection, id, params) {
	let traffic = ubus.call('state', 'traffic');

	if (!traffic)
		return send_response(connection, response_error(id, ERROR_INTERNAL, 'Failed to retrieve traffic information'));

	send_response(connection, response_success(id, traffic));
}

let handlers = {
	'ping':            { handler: handle_ping,            auth_required: true },
	'login':           { handler: handle_login,           auth_required: false },
	'logout':          { handler: handle_logout,          auth_required: true },
	'change-password': { handler: handle_change_password, auth_required: true },
	'devices':         { handler: handle_devices,         auth_required: true },
	'traffic':         { handler: handle_traffic,         auth_required: true },
};

let ctx = {
	send_response,
	send_event,
	broadcast_event,
	mode
};

if (mode == 'ucoord')
	register_ucoord(handlers, ctx);
else
	register_local(handlers, ctx);

function route_method(connection, request) {
	let method = handlers[request.method];
	if (!method)
		return send_response(connection, response_error(request.id, ERROR_METHOD_NOT_FOUND, 'Method not found'));

	if (method.auth_required && !connection.data().authenticated)
		return send_response(connection, response_error(request.id, ERROR_LOGIN_REQUIRED, 'login-required'));

	method.handler(connection, request.id, request.params);
}

export function onConnect(connection, protocols) {
	if (global.shutdown)
		return connection.close(1001, 'Server shutting down');

	if (!('ui' in protocols))
		return connection.close(1003, 'Unsupported protocol requested');

	let ctx = {
		authenticated: false,
		msg: ''
	};
	connection.data(ctx);

	let name = connection_name(connection);
	global.connections[name] = connection;

	uloop.timer(200, () => {
		send_event(connection, 'login-required');
	});

	return connection.accept('ui');
};

export function onClose(connection, code, reason) {
	let name = connection_name(connection);
	delete global.connections[name];
};

export function onData(connection, data, final) {
	let ctx = connection.data();
	if (!ctx)
		return connection.close(1009, 'Message too big');

	if (length(ctx.msg) + length(data) > 32 * 1024)
		return connection.close(1009, 'Message too big');

	ctx.msg = ctx.msg + data;
	if (!final)
		return;

	let request = parse_request(ctx.msg);
	ctx.msg = '';

	if (request.error)
		return send_response(connection, response_error(request.id, request.error, request.message));

	route_method(connection, request);
};
