'use strict';

import { readfile, writefile } from 'fs';
import * as ubus from 'ubus';
import * as uloop from 'uloop';
import {
	ERROR_INVALID_PARAMS,
	ERROR_INTERNAL,
	response_success,
	response_error
} from 'uconfig.webui.uwsd.jsonrpc';
import * as wiphy from 'uconfig.wiphy';
import * as board_json from 'uconfig.board_json';
import { token_generate_for_type } from 'uconfig.webui.uwsd.upload';

const ACTIVE_CONFIG_PATH = '/etc/uconfig/configs/uconfig.active';
const PENDING_CONFIG_PATH = '/tmp/uconfig.pending';
const APPLY_RESULT_PATH = '/tmp/uconfig/apply.json';
const DEFER_MS = 1000;
const STANDALONE_VENUE = 'local';

let send_response;
let broadcast_event;

let capabilities = {
	compatible: board_json.compatible,
	model: board_json.model_name,
	network: board_json.network,
};
if (board_json.macaddr)
	capabilities.macaddr = board_json.macaddr;
if (board_json.label_macaddr)
	capabilities.label_macaddr = board_json.label_macaddr;

function apply_result() {
	let content = readfile(APPLY_RESULT_PATH);
	if (!content)
		return {};
	return json(content) ?? {};
}

function config_test_run() {
	return system(`uconfig-apply -t ${PENDING_CONFIG_PATH}`);
}

function handle_config_get(connection, id, params) {
	let content = readfile(ACTIVE_CONFIG_PATH);
	if (!content)
		return send_response(connection, response_error(id, ERROR_INTERNAL, 'no active config'));

	let config = json(content);
	if (!config)
		return send_response(connection, response_error(id, ERROR_INTERNAL, 'failed to parse active config'));

	send_response(connection, response_success(id, config));
}

function handle_config_test(connection, id, params) {
	if (type(params) != 'object' || !params.config)
		return send_response(connection, response_error(id, ERROR_INVALID_PARAMS, 'Invalid params'));

	writefile(PENDING_CONFIG_PATH, sprintf('%.J', params.config));

	if (config_test_run() != 0)
		return send_response(connection, response_error(id, ERROR_INTERNAL, 'config test failed'));

	send_response(connection, response_success(id, apply_result()));
}

function handle_config_apply(connection, id, params) {
	if (type(params) != 'object' || !params.config)
		return send_response(connection, response_error(id, ERROR_INVALID_PARAMS, 'Invalid params'));

	writefile(PENDING_CONFIG_PATH, sprintf('%.J', params.config));

	if (config_test_run() != 0)
		return send_response(connection, response_error(id, ERROR_INTERNAL, 'config test failed'));

	send_response(connection, response_success(id, apply_result()));

	uloop.timer(DEFER_MS, () => system(`uconfig-apply ${PENDING_CONFIG_PATH}`));
}

function handle_system_info(connection, id, params) {
	let info = ubus.call('system', 'info');
	if (!info)
		return send_response(connection, response_error(id, ERROR_INTERNAL, 'ubus call failed'));

	send_response(connection, response_success(id, info));
}

// The client resolves the device it manages out of `status` before login
// completes, so a standalone AP describes itself in the shape a coordinator
// uses for a venue full of peers.
function handle_status(connection, id, params) {
	let board = ubus.call('system', 'board');
	if (!board)
		return send_response(connection, response_error(id, ERROR_INTERNAL, 'ubus call failed'));

	let peers = {};
	peers[board.hostname ?? capabilities.model] = {
		state: 'connected',
		ts: time(),
		capabilities,
		board,
	};

	let venues = {};
	venues[STANDALONE_VENUE] = peers;

	send_response(connection, response_success(id, { venues }));
}

function handle_capabilities(connection, id, params) {
	if (!board_json.board)
		return send_response(connection, response_error(id, ERROR_INTERNAL, 'capabilities not available'));

	send_response(connection, response_success(id, { capabilities, wiphy: wiphy.phys }));
}

function handle_reboot(connection, id, params) {
	send_response(connection, response_success(id, { ok: true }));
	broadcast_event?.('rebooting');
	uloop.timer(DEFER_MS, () => system('reboot'));
}

function handle_factory_reset(connection, id, params) {
	send_response(connection, response_success(id, { ok: true }));
	broadcast_event?.('factory-reset');
	uloop.timer(DEFER_MS, () => system('factoryreset -y -r'));
}

// Firmware is uploaded out-of-band via HTTP PUT /upload/<token> (see upload.uc):
// 'token' hands out a one-shot upload URL, 'apply' flashes the validated image.
function handle_sysupgrade(connection, id, params) {
	let action = type(params) == 'object' ? params.action : null;

	if (action == 'token') {
		let result = token_generate_for_type('sysupgrade');
		if (result.error)
			return send_response(connection, response_error(id, ERROR_INTERNAL, result.error));
		return send_response(connection, response_success(id, result));
	}

	if (action == 'apply') {
		let path = params.file_id ? global.uploaded_files?.[params.file_id] : null;
		if (!path)
			return send_response(connection, response_error(id, ERROR_INVALID_PARAMS, 'Invalid or missing file_id'));

		let flags = params.keep_config ? '' : '-n';
		send_response(connection, response_success(id, { ok: true, upgrade: true }));
		broadcast_event?.('upgrading');
		uloop.timer(DEFER_MS, () => system(`sysupgrade ${flags} ${path}`));
		return;
	}

	send_response(connection, response_error(id, ERROR_INVALID_PARAMS, 'Invalid action'));
}

export function register(handlers, ctx) {
	send_response = ctx.send_response;
	broadcast_event = ctx.broadcast_event;

	handlers['config-get']    = { handler: handle_config_get,    auth_required: true };
	handlers['config-test']   = { handler: handle_config_test,   auth_required: true };
	handlers['config-apply']  = { handler: handle_config_apply,  auth_required: true };
	handlers['system-info']   = { handler: handle_system_info,   auth_required: true };
	handlers['info']          = { handler: handle_system_info,   auth_required: true };
	handlers['status']        = { handler: handle_status,        auth_required: true };
	handlers['capabilities']  = { handler: handle_capabilities,  auth_required: true };
	handlers['reboot']        = { handler: handle_reboot,        auth_required: true };
	handlers['factory-reset'] = { handler: handle_factory_reset, auth_required: true };
	handlers['sysupgrade']    = { handler: handle_sysupgrade,    auth_required: true };
};
