'use strict';

import * as ubus from 'ubus';
import {
	ERROR_METHOD_NOT_FOUND,
	ERROR_INVALID_PARAMS,
	ERROR_INTERNAL,
	response_success,
	response_error
} from 'uconfig.webui.uwsd.jsonrpc';

let send_response;

// The mutating methods of wifi-dyn reply with a bare ubus status and no data, so
// a successful call and a failed one both hand back null and only the error
// tells them apart. That error latches and clears on read, so every call drains
// it exactly once here: a status left behind by one call would otherwise be
// reported against the next.
function wifi_dyn_call(method, args) {
	let data = ubus.call('wifi-dyn', method, args);

	return { data, status: ubus.error(true) };
}

// wifi-dynamic ships as a package of its own, and ubus reports both a missing
// object and the daemon's own "no such dynamic network" as STATUS_NOT_FOUND.
// The object is only looked up once a call has already failed that way.
function wifi_dyn_present() {
	return type(ubus.list('wifi-dyn')) == 'array';
}

function error_response(id, status) {
	if (status == ubus.STATUS_NOT_FOUND && !wifi_dyn_present())
		return response_error(id, ERROR_METHOD_NOT_FOUND, 'Dynamic wifi is not available on this device');

	if (status == ubus.STATUS_NOT_FOUND)
		return response_error(id, ERROR_INVALID_PARAMS, 'No dynamic wifi on that network');

	// What the daemon returns when the network already carries one, rather than
	// anything to do with permissions.
	if (status == ubus.STATUS_PERMISSION_DENIED)
		return response_error(id, ERROR_INVALID_PARAMS, 'That network already carries a dynamic wifi');

	if (status == ubus.STATUS_INVALID_ARGUMENT)
		return response_error(id, ERROR_INVALID_PARAMS, 'Invalid params', { status });

	return response_error(id, ERROR_INTERNAL, 'Failed to reach the dynamic wifi service', { status });
}

// `dump` carries the configuration and `status` the time left, the latter
// because the uloop timer behind it does not survive serialisation. Merged so a
// network reads the same whether it arrived from list or from status.
function network_entry(name, entry) {
	let rv = {
		network: name,
		active: true,
		ssid: entry?.config?.ssid,
		key: entry?.config?.key,
		encryption: entry?.config?.encryption,
		bands: entry?.bands,
	};

	let status = wifi_dyn_call('status', { network: name }).data;
	if (status?.remaining != null)
		rv.remaining = status.remaining;

	return rv;
}

function action_list(connection, id, params) {
	let res = wifi_dyn_call('dump');

	if (res.status != null)
		return send_response(connection, error_response(id, res.status));

	let networks = [];
	for (let name, entry in res.data)
		push(networks, network_entry(name, entry));

	send_response(connection, response_success(id, { networks }));
}

function action_status(connection, id, params) {
	let res = wifi_dyn_call('dump');

	if (res.status != null)
		return send_response(connection, error_response(id, res.status));

	let entry = res.data?.[params.network];
	if (!entry)
		return send_response(connection, response_success(id, { network: params.network, active: false }));

	send_response(connection, response_success(id, network_entry(params.network, entry)));
}

// Value rules are the daemon's: it owns the key and ssid lengths and decides
// whether the network exists. Repeating them here would be a second copy to
// drift. Only the presence of what it needs is checked, which is this layer's
// own business.
function action_add(connection, id, params) {
	let args = {
		network: params.network,
		ssid: params.ssid,
		key: params.key,
		encryption: params.encryption,
		bands: params.bands,
	};

	if (params.timeout != null)
		args.timeout = params.timeout;

	let status = wifi_dyn_call('add', args).status;
	if (status != null)
		return send_response(connection, error_response(id, status));

	send_response(connection, response_success(id, { success: true }));
}

function action_remove(connection, id, params) {
	let status = wifi_dyn_call('remove', { network: params.network }).status;

	if (status != null)
		return send_response(connection, error_response(id, status));

	send_response(connection, response_success(id, { success: true }));
}

function action_update(connection, id, params) {
	let status = wifi_dyn_call('update', { network: params.network, timeout: params.timeout }).status;

	if (status != null)
		return send_response(connection, error_response(id, status));

	send_response(connection, response_success(id, { success: true }));
}

const ACTIONS = {
	list:   { handler: action_list,   required: [] },
	status: { handler: action_status, required: [ 'network' ] },
	add:    { handler: action_add,    required: [ 'network', 'ssid', 'key', 'encryption', 'bands' ] },
	remove: { handler: action_remove, required: [ 'network' ] },
	update: { handler: action_update, required: [ 'network', 'timeout' ] },
};

function param_missing(params, names) {
	for (let name in names)
		if (params[name] == null)
			return name;
}

function handle_wifi_dynamic(connection, id, params) {
	if (type(params) != 'object')
		params = {};

	let action = type(params.action) == 'string' ? ACTIONS[params.action] : null;
	if (!action)
		return send_response(connection, response_error(id, ERROR_INVALID_PARAMS,
			`Unknown action, expected one of: ${join(', ', sort(keys(ACTIONS)))}`));

	let missing = param_missing(params, action.required);
	if (missing)
		return send_response(connection, response_error(id, ERROR_INVALID_PARAMS, `Missing parameter: ${missing}`));

	action.handler(connection, id, params);
}

export function register(handlers, ctx) {
	send_response = ctx.send_response;

	handlers['wifi-dynamic'] = { handler: handle_wifi_dynamic, auth_required: true };
};
