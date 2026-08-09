'use strict';

import * as ubus from 'ubus';
import {
	ERROR_METHOD_NOT_FOUND,
	ERROR_INTERNAL,
	response_success,
	response_error
} from 'uconfig.webui.uwsd.jsonrpc';

let send_response;

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

function handle_radios(connection, id, params) {
	let radios = ubus.call('state', 'radios');

	if (!radios)
		return send_response(connection, response_error(id, ERROR_INTERNAL, 'Failed to retrieve radio information'));

	send_response(connection, response_success(id, radios));
}

function handle_ports(connection, id, params) {
	// Forward the filter only when the client sends one, so an omitted
	// parameter still yields every socket.
	let args = {};
	if (type(params) == 'object' && params.network)
		args.network = params.network;

	let ports = ubus.call('state', 'ports', args);

	if (!ports)
		return send_response(connection, response_error(id, ERROR_INTERNAL, 'Failed to retrieve port information'));

	send_response(connection, response_success(id, ports));
}

function handle_network(connection, id, params) {
	let network = ubus.call('state', 'network');

	if (!network)
		return send_response(connection, response_error(id, ERROR_INTERNAL, 'Failed to retrieve network information'));

	send_response(connection, response_success(id, network));
}

function handle_event_log(connection, id, params) {
	let log = ubus.call('event', 'log');

	if (!log)
		return send_response(connection, response_error(id, ERROR_INTERNAL, 'Failed to retrieve the event log'));

	send_response(connection, response_success(id, log));
}

// The memory watcher ships in a package of its own, so a missing object means
// this device cannot report memory rather than that the call failed.
function handle_memory(connection, id, params) {
	let memory = ubus.call('memory', 'info');

	if (!memory)
		return send_response(connection, response_error(id, ERROR_METHOD_NOT_FOUND, 'Memory reporting is not installed on this device'));

	send_response(connection, response_success(id, memory));
}

export function register(handlers, ctx) {
	send_response = ctx.send_response;

	handlers['devices']   = { handler: handle_devices,   auth_required: true };
	handlers['traffic']   = { handler: handle_traffic,   auth_required: true };
	handlers['radios']    = { handler: handle_radios,    auth_required: true };
	handlers['ports']     = { handler: handle_ports,     auth_required: true };
	handlers['network']   = { handler: handle_network,   auth_required: true };
	handlers['event-log'] = { handler: handle_event_log, auth_required: true };
	handlers['memory']    = { handler: handle_memory,    auth_required: true };
};
