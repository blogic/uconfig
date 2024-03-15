/* Copyright (C) 2024 John Crispin <john@phrozen.org> */

'use strict';

import * as state from 'uconfig.state';

export function clients(connection, msg) {
	return state.dump_clients();
};

export function ssids(connection, msg) {
	return state.dump_ssids();
};

export function ports(connection, msg) {
	return state.network_devices();
};
