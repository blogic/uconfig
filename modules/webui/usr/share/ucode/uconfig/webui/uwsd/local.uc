'use strict';

import { readfile, writefile, unlink } from 'fs';
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

const ACTIVE_CONFIG_PATH = '/etc/uconfig/configs/uconfig.active';
const PENDING_CONFIG_PATH = '/tmp/uconfig.pending';
const APPLY_RESULT_PATH = '/tmp/uconfig/apply.json';
const SYSUPGRADE_IMG = '/tmp/sysupgrade.img';
const DEFER_MS = 1000;

let send_response;

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

function handle_capabilities(connection, id, params) {
	if (!board_json.board)
		return send_response(connection, response_error(id, ERROR_INTERNAL, 'capabilities not available'));

	send_response(connection, response_success(id, { capabilities, wiphy: wiphy.phys }));
}

function handle_reboot(connection, id, params) {
	send_response(connection, response_success(id, { ok: true }));
	uloop.timer(DEFER_MS, () => system('reboot'));
}

function handle_sysupgrade(connection, id, params) {
	if (type(params) != 'object' || !params.url)
		return send_response(connection, response_error(id, ERROR_INVALID_PARAMS, 'Invalid params'));

	if (system(`uclient-fetch -q -o ${SYSUPGRADE_IMG} ${params.url}`) != 0) {
		unlink(SYSUPGRADE_IMG);
		return send_response(connection, response_error(id, ERROR_INTERNAL, 'download failed'));
	}

	if (system(`sysupgrade -T ${SYSUPGRADE_IMG}`) != 0) {
		unlink(SYSUPGRADE_IMG);
		return send_response(connection, response_error(id, ERROR_INTERNAL, 'image validation failed'));
	}

	if (params.action == 'test') {
		unlink(SYSUPGRADE_IMG);
		return send_response(connection, response_success(id, { ok: true }));
	}

	send_response(connection, response_success(id, { ok: true, upgrade: true }));

	uloop.timer(DEFER_MS, () => system(`sysupgrade ${SYSUPGRADE_IMG}`));
}

export function register(handlers, ctx) {
	send_response = ctx.send_response;

	handlers['config-get']   = { handler: handle_config_get,   auth_required: true };
	handlers['config-test']  = { handler: handle_config_test,  auth_required: true };
	handlers['config-apply'] = { handler: handle_config_apply, auth_required: true };
	handlers['system-info']  = { handler: handle_system_info,  auth_required: true };
	handlers['capabilities'] = { handler: handle_capabilities, auth_required: true };
	handlers['reboot']       = { handler: handle_reboot,       auth_required: true };
	handlers['sysupgrade']   = { handler: handle_sysupgrade,   auth_required: true };
};
