'use strict';

import * as fs from 'fs';
import * as digest from 'digest';

const CREDENTIALS_FILE = '/etc/uconfig/webui/credentials';
const MIN_PASSWORD_LENGTH = 8;
const MAX_PASSWORD_LENGTH = 64;

let users;

function load_credentials() {
	let data = fs.readfile(CREDENTIALS_FILE);
	if (data)
		users = json(data);
	users ??= { admin: {} };
}

function save_credentials() {
	fs.writefile(CREDENTIALS_FILE, users);
}

function validate_password(username, password) {
	if (!username || !password || !users[username]?.hash)
		return false;

	let hash = digest.sha512(password);

	return hash == users[username].hash;
}

function login(password) {
	if (!validate_password('admin', password))
		return null;

	return { success: true };
}

function change_password(new_password) {
	if (type(new_password) != 'string')
		return { error: 'Password must be a string' };

	if (length(new_password) < MIN_PASSWORD_LENGTH)
		return { error: `Password must be at least ${MIN_PASSWORD_LENGTH} characters` };

	if (length(new_password) > MAX_PASSWORD_LENGTH)
		return { error: `Password must not exceed ${MAX_PASSWORD_LENGTH} characters` };

	if (!users.admin)
		users.admin = {};

	users.admin.hash = digest.sha512(new_password);
	save_credentials();

	return { success: true };
}

load_credentials();

export {
	login,
	change_password
};
