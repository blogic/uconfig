'use strict';

const ERROR_PARSE = -32700;
const ERROR_INVALID_REQUEST = -32600;
const ERROR_METHOD_NOT_FOUND = -32601;
const ERROR_INVALID_PARAMS = -32602;
const ERROR_INTERNAL = -32603;
const ERROR_LOGIN_REQUIRED = -32001;
const ERROR_INVALID_PASSWORD = -32000;

function parse_request(data) {
	let request;

	try {
		request = json(data);
	} catch (e) {
		return {
			error: ERROR_PARSE,
			message: 'Parse error',
			id: null
		};
	}

	if (type(request) != 'object')
		return {
			error: ERROR_INVALID_REQUEST,
			message: 'Invalid Request',
			id: null
		};

	if (request.jsonrpc != '2.0')
		return {
			error: ERROR_INVALID_REQUEST,
			message: 'Invalid Request',
			id: request.id ?? null
		};

	if (!request.method || type(request.method) != 'string')
		return {
			error: ERROR_INVALID_REQUEST,
			message: 'Invalid Request',
			id: request.id ?? null
		};

	return {
		valid: true,
		id: request.id,
		method: request.method,
		params: request.params ?? {}
	};
}

function response_success(id, result) {
	return {
		jsonrpc: '2.0',
		id: id,
		result: result
	};
}

function response_error(id, code, message, data) {
	let error = {
		code: code,
		message: message
	};

	if (data != null)
		error.data = data;

	return {
		jsonrpc: '2.0',
		id: id,
		error: error
	};
}

export {
	ERROR_PARSE,
	ERROR_INVALID_REQUEST,
	ERROR_METHOD_NOT_FOUND,
	ERROR_INVALID_PARAMS,
	ERROR_INTERNAL,
	ERROR_LOGIN_REQUIRED,
	ERROR_INVALID_PASSWORD,
	parse_request,
	response_success,
	response_error
};
