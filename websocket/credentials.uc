/* copyright (c) 2024 john crispin <john@phrozen.org> */

'use strict';

import * as utils from 'uconfig.utils';
import * as math from 'math';
import * as fs from 'fs';

let users = fs.readfile('/etc/uconfig/credentials');
if (users)
	users = json(users);
users ??= {
	'admin': {}
};
math.srand(time());

function random_string(len) {
	let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
	let mod = length(chars) - 1;
	let str = '';

	for (let  i = 0; i < len; i++)
		str += substr(chars, math.rand() % mod, 1);

	return str;
}

export function exist(username) {
	return users[username];
};

export function login(username, password) {
	if (!username || !password || !users[username]?.crypt ||
	    users[username].crypt != utils.crypt(password, `$5$${split(users[username].crypt, '$')[2]}`))
		return null;
	
	return users[username];
};

export function passwd(username, password) {
	if (!users[username] || !password)
		return;

	users[username].crypt = utils.crypt(password, `$5$${random_string(16)}`);;

	fs.writefile('/etc/uconfig/credentials', users);
};
