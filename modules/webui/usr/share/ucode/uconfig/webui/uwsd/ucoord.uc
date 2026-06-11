'use strict';

import {
	ERROR_INVALID_PARAMS,
	ERROR_INTERNAL,
	response_success,
	response_error
} from 'uconfig.webui.uwsd.jsonrpc';

import * as ubus from 'ubus';

let send_response;

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

export function register(handlers, ctx) {
	send_response = ctx.send_response;

	handlers['list']         = { handler: handle_list,         auth_required: true };
	handlers['status']       = { handler: handle_status,       auth_required: true };
	handlers['info']         = { handler: handle_info,         auth_required: true };
	handlers['system-info']  = { handler: handle_system_info,  auth_required: true };
	handlers['config-get']   = { handler: handle_config_get,   auth_required: true };
	handlers['config-test']  = { handler: handle_config_test,  auth_required: true };
	handlers['config-apply'] = { handler: handle_config_apply, auth_required: true };
	handlers['reboot']       = { handler: handle_reboot,       auth_required: true };
	handlers['sysupgrade']   = { handler: handle_sysupgrade,   auth_required: true };
	handlers['include']      = { handler: handle_include,      auth_required: true };
	handlers['capabilities'] = { handler: handle_capabilities, auth_required: true };
	handlers['reload']       = { handler: handle_reload,       auth_required: true };
};
