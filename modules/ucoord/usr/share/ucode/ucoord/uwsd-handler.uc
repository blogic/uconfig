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
} from 'ucoord.uwsd.jsonrpc';

import { login, change_password } from 'ucoord.uwsd.auth';
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

function ubus_proxy(connection, id, method, args) {
	let pending = ubus.defer({
		object: 'ucoord',
		method: method,
		data: args,
		cb: function(status, response) {
			if (status != 0)
				return send_response(connection, response_error(id, ERROR_INTERNAL, `ubus error: ${status}`));
			if (response?.ok == false)
				return send_response(connection, response_error(id, ERROR_INTERNAL, response.error ?? 'unknown error'));
			if (response?.ok == true)
				return send_response(connection, response_success(id, response.data));
			send_response(connection, response_success(id, response));
		}
	});

	if (!pending)
		send_response(connection, response_error(id, ERROR_INTERNAL, 'Failed to call ucoord'));
}

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
	send_response(connection, response_success(id, result));
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

function handle_list(connection, id, params) {
	ubus_proxy(connection, id, 'status', {});
}

function handle_status(connection, id, params) {
	ubus_proxy(connection, id, 'status', {});
}

function handle_info(connection, id, params) {
	if (type(params) != 'object' || !params.venue || !params.peer)
		return send_response(connection, response_error(id, ERROR_INVALID_PARAMS, 'Invalid params'));

	let args = { venue: params.venue, peer: params.peer };
	if (params.timeout)
		args.timeout = params.timeout;

	ubus_proxy(connection, id, 'info', args);
}

function handle_state(connection, id, params) {
	if (type(params) != 'object' || !params.venue || !params.peer)
		return send_response(connection, response_error(id, ERROR_INVALID_PARAMS, 'Invalid params'));

	let args = { venue: params.venue, peer: params.peer };
	if (params.timeout)
		args.timeout = params.timeout;

	ubus_proxy(connection, id, 'state', args);
}

function handle_config_get(connection, id, params) {
	if (type(params) != 'object' || !params.venue || !params.peer)
		return send_response(connection, response_error(id, ERROR_INVALID_PARAMS, 'Invalid params'));

	let args = { venue: params.venue, peer: params.peer, action: 'get' };
	if (params.timeout)
		args.timeout = params.timeout;

	ubus_proxy(connection, id, 'configure', args);
}

function handle_config_apply(connection, id, params) {
	if (type(params) != 'object' || !params.venue || !params.peer || !params.config)
		return send_response(connection, response_error(id, ERROR_INVALID_PARAMS, 'Invalid params'));

	let args = { venue: params.venue, peer: params.peer, action: 'apply', config: params.config };
	if (params.timeout)
		args.timeout = params.timeout;

	ubus_proxy(connection, id, 'configure', args);
}

function handle_config_test(connection, id, params) {
	if (type(params) != 'object' || !params.venue || !params.peer || !params.config)
		return send_response(connection, response_error(id, ERROR_INVALID_PARAMS, 'Invalid params'));

	let args = { venue: params.venue, peer: params.peer, action: 'test', config: params.config };
	if (params.timeout)
		args.timeout = params.timeout;

	ubus_proxy(connection, id, 'configure', args);
}

function handle_reboot(connection, id, params) {
	if (type(params) != 'object' || !params.venue || !params.peer)
		return send_response(connection, response_error(id, ERROR_INVALID_PARAMS, 'Invalid params'));

	let args = { venue: params.venue, peer: params.peer };
	if (params.timeout)
		args.timeout = params.timeout;

	ubus_proxy(connection, id, 'reboot', args);
}

function handle_sysupgrade(connection, id, params) {
	if (type(params) != 'object' || !params.venue || !params.peer || !params.url)
		return send_response(connection, response_error(id, ERROR_INVALID_PARAMS, 'Invalid params'));

	let args = { venue: params.venue, peer: params.peer, url: params.url };
	if (params.timeout)
		args.timeout = params.timeout;

	ubus_proxy(connection, id, 'sysupgrade', args);
}

function handle_include(connection, id, params) {
	if (type(params) != 'object' || !params.venue || !params.action)
		return send_response(connection, response_error(id, ERROR_INVALID_PARAMS, 'Invalid params'));

	if (params.action != 'list' && !params.name)
		return send_response(connection, response_error(id, ERROR_INVALID_PARAMS, 'Invalid params'));

	let args = { venue: params.venue, action: params.action };
	if (params.name)
		args.name = params.name;
	if (params.content)
		args.content = params.content;
	if (params.timeout)
		args.timeout = params.timeout;

	ubus_proxy(connection, id, 'include', args);
}

function handle_system_info(connection, id, params) {
	if (type(params) != 'object' || !params.venue || !params.peer)
		return send_response(connection, response_error(id, ERROR_INVALID_PARAMS, 'Invalid params'));

	let args = { venue: params.venue, peer: params.peer };
	if (params.timeout)
		args.timeout = params.timeout;

	ubus_proxy(connection, id, 'info', args);
}

function handle_capabilities(connection, id, params) {
	if (type(params) != 'object' || !params.venue || !params.peer)
		return send_response(connection, response_error(id, ERROR_INVALID_PARAMS, 'Invalid params'));

	let args = { venue: params.venue, peer: params.peer };
	if (params.timeout)
		args.timeout = params.timeout;

	ubus_proxy(connection, id, 'capabilities', args);
}

function handle_reload(connection, id, params) {
	ubus_proxy(connection, id, 'reload', {});
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
	'list':            { handler: handle_list,             auth_required: true },
	'status':          { handler: handle_status,           auth_required: true },
	'info':            { handler: handle_info,             auth_required: true },
	'state':           { handler: handle_state,            auth_required: true },
	'config-get':      { handler: handle_config_get,      auth_required: true },
	'config-apply':    { handler: handle_config_apply,    auth_required: true },
	'config-test':     { handler: handle_config_test,     auth_required: true },
	'reboot':          { handler: handle_reboot,           auth_required: true },
	'sysupgrade':      { handler: handle_sysupgrade,      auth_required: true },
	'include':         { handler: handle_include,          auth_required: true },
	'system-info':     { handler: handle_system_info,      auth_required: true },
	'capabilities':    { handler: handle_capabilities,     auth_required: true },
	'reload':          { handler: handle_reload,           auth_required: true },
	'devices':         { handler: handle_devices,          auth_required: true },
	'traffic':         { handler: handle_traffic,          auth_required: true },
};

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
