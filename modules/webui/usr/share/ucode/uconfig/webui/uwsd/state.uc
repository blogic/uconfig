'use strict';

import * as ubus from 'ubus';
import { popen } from 'fs';
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

function handle_cpu(connection, id, params) {
	let cpu = ubus.call('state', 'cpu');

	if (!cpu)
		return send_response(connection, response_error(id, ERROR_INTERNAL, 'Failed to retrieve CPU information'));

	send_response(connection, response_success(id, cpu));
}

function handle_thermal(connection, id, params) {
	let thermal = ubus.call('state', 'thermal');

	if (!thermal)
		return send_response(connection, response_error(id, ERROR_INTERNAL, 'Failed to retrieve thermal information'));

	send_response(connection, response_success(id, thermal));
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

// procd owns the `log` object, so it is another process and a synchronous call
// cannot deadlock. `stream: false` is what makes it answer once rather than
// subscribe; the advertised `oneshot` flag returns nothing at all.
//
// No `lines`: omitting it returns the whole buffer, which is what the UI wants.
// The buffer is already bounded, by system.log_size, so this cannot run away.
// Passing `lines: 0` would return nothing rather than everything.
function handle_syslog(connection, id, params) {
	let log = ubus.call('log', 'read', { stream: false });

	if (!log)
		return send_response(connection, response_error(id, ERROR_INTERNAL, 'Failed to retrieve the system log'));

	send_response(connection, response_success(id, log));
}

// When the machine booted, in epoch milliseconds. Only accurate to the second,
// which is the resolution system.info reports uptime at.
function boot_ms() {
	let info = ubus.call('system', 'info');

	if (!info?.uptime)
		return null;

	return (time() - info.uptime) * 1000;
}

// `dmesg -r` keeps the priority prefix: <PRI>[ SECONDS.MICROS] message. Parsed
// by hand rather than by regex because ucode uses POSIX ERE, where the digit
// and whitespace shorthands do not exist. Anything unrecognised still returns
// as a message: a line rendered without its priority beats a dropped line.
function dmesg_parse(line) {
	let text = rtrim(line, '\n');

	if (substr(text, 0, 1) != '<')
		return { priority: null, time: null, msg: text };

	let close = index(text, '>');

	if (close < 0)
		return { priority: null, time: null, msg: text };

	let priority = +substr(text, 1, close - 1);
	let rest = substr(text, close + 1);

	if (substr(rest, 0, 1) != '[')
		return { priority, time: null, msg: rest };

	let end = index(rest, ']');

	if (end < 0)
		return { priority, time: null, msg: rest };

	return {
		priority,
		time: +trim(substr(rest, 1, end - 1)),
		msg: ltrim(substr(rest, end + 1))
	};
}

// The kernel stamps monotonic seconds since boot and syslog stamps epoch
// milliseconds. Convert, so one page can render both against the same clock and
// the two logs can be read against each other.
function dmesg_entry(line, base) {
	let entry = dmesg_parse(line);

	if (base != null && entry.time != null)
		entry.time = base + int(entry.time * 1000);

	return entry;
}

// The whole ring buffer. It is fixed size and dmesg exits at the end of it, so
// there is nothing here to bound that the kernel has not bounded already.
function handle_dmesg(connection, id, params) {
	let p = popen('dmesg -r');

	if (!p)
		return send_response(connection, response_error(id, ERROR_INTERNAL, 'Failed to read the kernel log'));

	let base = boot_ms();
	let log = [];
	let line;

	while ((line = p.read('line')) != null)
		push(log, dmesg_entry(line, base));

	p.close();

	send_response(connection, response_success(id, { log }));
}

export function register(handlers, ctx) {
	send_response = ctx.send_response;

	handlers['devices']   = { handler: handle_devices,   auth_required: true };
	handlers['traffic']   = { handler: handle_traffic,   auth_required: true };
	handlers['cpu']       = { handler: handle_cpu,       auth_required: true };
	handlers['thermal']   = { handler: handle_thermal,   auth_required: true };
	handlers['radios']    = { handler: handle_radios,    auth_required: true };
	handlers['ports']     = { handler: handle_ports,     auth_required: true };
	handlers['network']   = { handler: handle_network,   auth_required: true };
	handlers['event-log'] = { handler: handle_event_log, auth_required: true };
	handlers['memory']    = { handler: handle_memory,    auth_required: true };
	handlers['syslog']    = { handler: handle_syslog,    auth_required: true };
	handlers['dmesg']     = { handler: handle_dmesg,     auth_required: true };
};
