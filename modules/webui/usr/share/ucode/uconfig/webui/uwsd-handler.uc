'use strict';

import {
	ERROR_METHOD_NOT_FOUND,
	ERROR_INVALID_PARAMS,
	ERROR_LOGIN_REQUIRED,
	ERROR_INVALID_PASSWORD,
	parse_request,
	response_success,
	response_error
} from 'uconfig.webui.uwsd.jsonrpc';

import { login, change_password } from 'uconfig.webui.uwsd.auth';
import { register as register_state } from 'uconfig.webui.uwsd.state';
import { register as register_storage } from 'uconfig.webui.uwsd.storage';
import { register as register_ucoord } from 'uconfig.webui.uwsd.ucoord';
import { register as register_local } from 'uconfig.webui.uwsd.local';
import {
	request_handle as upload_request_handle,
	body_handle as upload_body_handle,
	file_validate as upload_file_validate,
	validation_event_send as upload_validation_event_send
} from 'uconfig.webui.uwsd.upload';
import { readfile } from 'fs';
import * as ubus from 'ubus';
import * as uloop from 'uloop';

const ACTIVE_CONFIG_PATH = '/etc/uconfig/configs/uconfig.active';

global.connections = {};
global.uploaded_files = {};

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

// A config carrying no top-level webui object has never been through the setup
// wizard. Such a device has no password to ask for yet, so the wizard runs in
// place of a login and the methods it needs answer without one. Re-read per
// call rather than latched at connect: the moment the wizard applies a config,
// the device is set up and the session logs in like any other. Standalone only,
// since the wizard configures the local device, which is not a coordinator's job.
function setup_required() {
	if (mode != 'standalone')
		return false;

	let content = readfile(ACTIVE_CONFIG_PATH);
	if (!content)
		return true;

	try {
		let config = json(content);
		return type(config) != 'object' || config.webui == null;
	} catch (e) {
		return true;
	}
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

let handlers = {
	'ping':            { handler: handle_ping,            auth_required: true },
	'login':           { handler: handle_login,           auth_required: false },
	'logout':          { handler: handle_logout,          auth_required: true },
	'change-password': { handler: handle_change_password, auth_required: true },
};

let ctx = {
	send_response,
	send_event,
	broadcast_event,
	mode
};

// Live state is read from this device's own daemons either way, so it is
// registered before the mode decides which configuration backend answers.
// Storage is the same: what is plugged into this device is this device's
// business whether or not a coordinator owns its configuration.
register_state(handlers, ctx);
register_storage(handlers, ctx);

if (mode == 'ucoord')
	register_ucoord(handlers, ctx);
else
	register_local(handlers, ctx);

function route_method(connection, request) {
	let method = handlers[request.method];
	if (!method)
		return send_response(connection, response_error(request.id, ERROR_METHOD_NOT_FOUND, 'Method not found'));

	if (method.auth_required && !connection.data().authenticated && !setup_required())
		return send_response(connection, response_error(request.id, ERROR_LOGIN_REQUIRED, 'login-required'));

	method.handler(connection, request.id, request.params);
}

export function onConnect(connection, protocols) {
	if (!('uconfig' in protocols))
		return connection.close(1003, 'Unsupported protocol requested');

	let ctx = {
		authenticated: false,
		msg: ''
	};
	connection.data(ctx);

	let name = connection_name(connection);
	global.connections[name] = connection;

	uloop.timer(200, () => {
		send_event(connection, setup_required() ? 'setup-required' : 'login-required');
	});

	return connection.accept('uconfig');
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

export function onRequest(request, method, uri) {
	let result = upload_request_handle(request, method, uri);
	if (result)
		return result;

	return request.reply({ 'Status': '404 Not Found', 'Content-Type': 'text/plain' }, 'Not Found');
};

export function onBody(request, data) {
	return upload_body_handle(request, data, upload_file_validate, (type, success, file_id, error) => {
		upload_validation_event_send(global.connections, type, success, file_id, error);
	}, global.uploaded_files);
};
