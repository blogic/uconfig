'use strict';

import * as fs from 'fs';

// One-shot, expiring upload tokens. A client requests a token via JSON-RPC,
// then HTTP PUTs the file to /upload/<token>; the token is consumed on use.
global.upload_tokens ??= {};

const SYSUPGRADE_MAX_SIZE = 50 * 1024 * 1024;
const TOKEN_EXPIRY_SECONDS = 600;

function token_generate(type, max_size, expires_seconds) {
	let now = time();
	let token = uwsd.uuid();

	global.upload_tokens[token] = {
		type,
		max_size,
		created: now,
		expires: now + expires_seconds,
		used: false
	};

	for (let old, data in global.upload_tokens)
		if (data.expires < now)
			delete global.upload_tokens[old];

	return { token, upload_url: `/upload/${token}`, max_size, expires_in: expires_seconds };
}

export function token_generate_for_type(type) {
	if (type == 'sysupgrade')
		return token_generate(type, SYSUPGRADE_MAX_SIZE, TOKEN_EXPIRY_SECONDS);
	return { error: 'Unknown upload type' };
};

function token_validate(token) {
	let now = time();
	let data = global.upload_tokens?.[token];

	if (!data)
		return { valid: false, error: 'Invalid or expired upload token' };

	if (data.expires < now) {
		delete global.upload_tokens[token];
		return { valid: false, error: 'Upload token has expired' };
	}

	if (data.used)
		return { valid: false, error: 'Upload token already used' };

	return { valid: true, data };
}

function upload_path_get(type, token) {
	if (type == 'sysupgrade')
		return `/tmp/sysupgrade.${time()}`;
	return `/tmp/upload.${token}`;
}

export function file_validate(file_path, type) {
	if (type != 'sysupgrade')
		return { success: false, error: 'Unknown file type' };

	if (system(`sysupgrade --test ${file_path}`) == 0)
		return { success: true };

	return { success: false, error: 'Firmware image validation failed' };
};

export function validation_event_send(connections, type, success, file_id, error) {
	let event = {
		jsonrpc: '2.0',
		method: success ? `${type}-validation-success` : `${type}-validation-failed`,
		params: success ? { file_id } : { error }
	};
	let data = sprintf('%.J', event);
	for (let name, conn in connections)
		conn.send(data);
};

export function request_handle(request, method, uri) {
	let m = match(uri, /^\/upload\/([a-f0-9-]+)$/);
	if (method != 'PUT' || !m)
		return false;

	let token = m[1];
	let validation = token_validate(token);
	if (!validation.valid)
		return request.reply({ 'Status': '403 Forbidden', 'Content-Type': 'text/plain' }, validation.error);

	let token_data = validation.data;
	let filesize = request.header('Content-Length');

	if (filesize == null)
		return request.reply({ 'Status': '411 Length Required', 'Content-Type': 'text/plain' }, 'The request must specify a Content-Length');

	if (!match(filesize, /^[0-9]+$/))
		return request.reply({ 'Status': '400 Bad Request', 'Content-Type': 'text/plain' }, 'Invalid Content-Length value');

	if (+filesize > token_data.max_size)
		return request.reply({ 'Status': '413 Payload Too Large', 'Content-Type': 'text/plain' }, sprintf('File size exceeds limit of %d bytes', token_data.max_size));

	let file_path = upload_path_get(token_data.type, token);
	let file_handle = fs.open(file_path, 'w');
	if (!file_handle)
		return request.reply({ 'Status': '500 Internal Server Error', 'Content-Type': 'text/plain' }, 'Failed to create upload file');

	global.upload_tokens[token].used = true;

	request.data({
		token,
		token_type: token_data.type,
		file_id: uwsd.uuid(),
		file_path,
		file_handle,
		filesize: +filesize,
		upload_start: time()
	});
	request.store(file_handle);
	return true;
};

export function body_handle(request, data, file_validate_fn, validation_event_send_fn, uploaded_files) {
	let m = match(request.uri(), /^\/upload\/([a-f0-9-]+)$/);
	if (request.method() != 'PUT' || !m)
		return false;

	// Non-empty chunks stream straight to the stored file handle; '' marks EOF.
	if (data != '')
		return true;

	let ctx = request.data();
	let upload_duration = time() - ctx.upload_start;
	ctx.file_handle.close();

	let validation = file_validate_fn(ctx.file_path, ctx.token_type);
	if (!validation.success) {
		fs.unlink(ctx.file_path);
		validation_event_send_fn(ctx.token_type, false, null, validation.error);
		return request.reply({ 'Status': '400 Bad Request', 'Content-Type': 'application/json' }, {
			status: 'validation_failed',
			error: validation.error
		});
	}

	uploaded_files[ctx.file_id] = ctx.file_path;
	validation_event_send_fn(ctx.token_type, true, ctx.file_id, null);
	return request.reply({ 'Status': '201 Created', 'Content-Type': 'application/json' }, {
		token: ctx.token,
		file_id: ctx.file_id,
		filesize: ctx.filesize,
		upload_duration,
		token_type: ctx.token_type,
		status: 'upload_complete'
	});
};
