'use strict';

import * as ubus from 'ubus';
import { readfile, writefile } from 'fs';
import { readjson } from 'uconfig.files';
import * as editor from 'cli.object-editor';
import * as uconfig from 'cli.uconfig';

let unetd = readjson('/etc/uconfig/data/unetd.json');
unetd.networks ??= {};
let enroll_ctx;

const active_config_path = '/etc/uconfig/configs/uconfig.active';

function active_config_interfaces() {
	let cfg = readjson(active_config_path);
	return keys(cfg.interfaces ?? {});
}

function unet_service_inject(interface_name) {
	let cfg = readjson(active_config_path);
	if (!cfg.interfaces?.[interface_name])
		return false;
	cfg.interfaces[interface_name].services ??= [];
	if (index(cfg.interfaces[interface_name].services, 'unet') < 0)
		push(cfg.interfaces[interface_name].services, 'unet');
	writefile(active_config_path, sprintf('%.J\n', cfg));
	return true;
}

function unet_service_cleanup() {
	let cfg = readjson(active_config_path);
	for (let name, iface in cfg.interfaces ?? {}) {
		if (!iface.services)
			continue;
		let idx = index(iface.services, 'unet');
		if (idx >= 0)
			splice(iface.services, idx, 1);
	}
	writefile(active_config_path, sprintf('%.J\n', cfg));
}

function unetd_store(name, data) {
	unetd.networks[name] = data;
	writefile('/etc/uconfig/data/unetd.json', sprintf('%.J\n', unetd));
	system('/usr/bin/uconfig-apply -u /etc/uconfig/configs/uconfig.active');
	ubus.call('ucoord', 'reload');
}

function unetd_delete(name) {
	delete unetd.networks[name];
	writefile('/etc/uconfig/data/unetd.json', sprintf('%.J\n', unetd));
	if (!length(keys(unetd.networks)))
		unet_service_cleanup();
	system('/usr/bin/uconfig-apply -u /etc/uconfig/configs/uconfig.active');
	ubus.call('ucoord', 'reload');
}

model.add_hook("unet_create", unetd_store);
model.add_hook("unet_update", unetd_store);
model.add_hook("unet_delete", unetd_delete);
model.add_hook("unet_network_init", function(name, network) {
	if (!match(name, /^ucoord_/))
		return;

	network.services.admin = { type: 'ucoord', members: ['main'] };
});
model.add_hook("unet_enroll", function(action) {
	enroll_ctx = null;
	ubus.call('ucoord', 'reload');
	if (global.ucoord?.on_enroll)
		global.ucoord.on_enroll(action);
});
push(model.uconfig.services, 'unet');

function password_get(ctx, prompt, confirm) {
	if (!model.cb.getpass) {
		ctx.invalid_argument('Could not get network config password');
		return;
	}
	let pw = model.cb.getpass(prompt ?? 'Network config password: ');
	if (length(pw) < 12) {
		ctx.invalid_argument('Password must be at least 12 characters long');
		return;
	}
	if (confirm) {
		let pw2 = model.cb.getpass('Confirm config password: ');
		if (pw != pw2) {
			ctx.invalid_argument('Password mismatch');
			return;
		}
	}
	return pw;
}

function format_duration(seconds) {
	if (seconds < 60)
		return `${seconds}s`;
	if (seconds < 3600)
		return sprintf('%dm %ds', seconds / 60, seconds % 60);
	if (seconds < 86400)
		return sprintf('%dh %dm', seconds / 3600, (seconds % 3600) / 60);
	return sprintf('%dd %dh', seconds / 86400, (seconds % 86400) / 3600);
}

function format_bytes(bytes) {
	if (bytes < 1024)
		return `${bytes} B`;
	if (bytes < 1048576)
		return sprintf('%.1f KB', bytes / 1024);
	if (bytes < 1073741824)
		return sprintf('%.1f MB', bytes / 1048576);
	return sprintf('%.1f GB', bytes / 1073741824);
}

function print_table(headers, rows) {
	let widths = map(headers, h => length(h));

	for (let row in rows)
		for (let i, cell in row)
			if (length('' + cell) > widths[i])
				widths[i] = length('' + cell);

	let sep = '+';
	for (let w in widths)
		sep += '-' + replace(sprintf('%*s', w, ''), ' ', '-', true) + '-+';
	printf('%s\n', sep);

	let header_line = '|';
	for (let i, h in headers)
		header_line += sprintf(' %-*s |', widths[i], h);
	printf('%s\n', header_line);
	printf('%s\n', sep);

	for (let row in rows) {
		let line = '|';
		for (let i, cell in row)
			line += sprintf(' %-*s |', widths[i], cell ?? '');
		printf('%s\n', line);
	}

	printf('%s\n', sep);
}

function local_network_derive(ctx, name) {
	let suffixes = ['', '_4', '_6'];

	for (let suffix in suffixes) {
		let candidate = name + suffix;
		let status = ubus.call('network.interface.' + candidate, 'status');
		if (!status || !status.up)
			continue;

		let has_addr = length(status['ipv4-address']) > 0 ||
			       length(status['ipv6-address']) > 0;
		if (has_addr)
			return candidate;
	}

	ctx.invalid_argument(`No usable netifd interface found for '${name}'`);
}

function venue_display_name(name) {
	return match(name, /^ucoord_/) ? substr(name, 7) : name;
}

function get_venues() {
	let config = readjson('/etc/uconfig/data/unetd.json');
	let networks = config.networks ?? {};
	let venues = {};
	for (let k in keys(networks))
		if (match(k, /^ucoord_/))
			venues[substr(k, 7)] = networks[k];
	return venues;
}

const ucoord_node = {
	join: {
		help: 'Join a coordination network',
		named_args: {
			'access-key': {
				help: 'Access key from invitation',
				required: true,
				args: { type: 'string' },
			},
			network: {
				help: 'Network interface for unet service',
				required: true,
				args: {
					type: 'enum',
					value: () => active_config_interfaces(),
				},
			},
		},
		call: function(ctx, argv, named) {
			let local_network = local_network_derive(ctx, named.network);
			if (!local_network)
				return;

			if (!unet_service_inject(named.network))
				return ctx.error('ERROR', `Interface '${named.network}' not found in active config`);

			let unet = model.context().select(['unet']);
			if (!unet)
				return ctx.error('ERROR', 'unet CLI module not available');

			let args = ['join', 'access-key', named['access-key'], 'local-network', local_network];
			let ret = unet.call(args);
			if (ret?.error)
				return ctx.error('FAILED', ret.error);

			enroll_ctx = unet;
			return ctx.ok('Successfully joined network');
		}
	},

	status: {
		help: 'Show coordinator status',
		call: function(ctx, argv) {
			let result = ubus.call('ucoord', 'status');
			if (!result)
				return ctx.error('UBUS_ERROR', 'ucoord service not available');

			let venues = result.venues ?? {};
			if (!length(keys(venues)))
				return ctx.ok('No venues configured');

			let now = time();
			for (let name, peers in venues) {
				printf('Venue: %s\n', venue_display_name(name));
				for (let peer, info in peers) {
					let ago = info.ts ? format_duration(now - info.ts) + ' ago' : 'unknown';
					printf('  %s: %s (seen %s)\n', peer, info.state ?? 'unknown', ago);
				}
			}

			return ctx.ok();
		}
	},

	list: {
		help: 'List all connected peers',
		call: function(ctx, argv) {
			let result = ubus.call('ucoord', 'status');
			if (!result)
				return ctx.error('UBUS_ERROR', 'ucoord service not available');

			let venues = result.venues ?? {};
			let headers = ['Venue', 'Peer', 'State', 'Last Seen'];
			let rows = [];
			let now = time();

			for (let venue, peers in venues)
				for (let peer, info in peers)
					push(rows, [
						venue_display_name(venue),
						peer,
						info.state ?? 'unknown',
						info.ts ? format_duration(now - info.ts) + ' ago' : 'unknown',
					]);

			if (!length(rows))
				return ctx.ok('No peers connected');

			print_table(headers, rows);
			return ctx.ok();
		}
	},
};

function host_select(peer_name, venue_name) {
	return {
		help: 'Select peer ' + peer_name,
		select_node: 'ucoord_host',
		select: function(ctx, argv) {
			return ctx.set(peer_name, { host: peer_name, venue: venue_name });
		},
	};
}

const ucoord_include = {
	list: {
		help: 'List include files',
		call: function(ctx, argv) {
			let venue = ctx.data.venue;
			let result = ubus.call('ucoord', 'include', { venue, action: 'list' });
			if (!result)
				return ctx.error('UBUS_ERROR', 'ucoord service not available');
			if (!result.ok)
				return ctx.error('FAILED', result.error ?? 'Failed to list includes');

			let data = result.data;
			if (!data || !length(keys(data)))
				return ctx.ok('No include files');

			let headers = ['Name', 'UUID'];
			let rows = [];
			for (let name, uuid in data)
				push(rows, [name, uuid]);

			print_table(headers, rows);
			return ctx.ok();
		}
	},

	show: {
		help: 'Show include file content',
		args: [
			{
				name: 'name',
				help: 'Include name',
				type: 'string',
				required: true,
			}
		],
		call: function(ctx, argv) {
			let venue = ctx.data.venue;
			let name = argv[0];
			let result = ubus.call('ucoord', 'include', { venue, action: 'get', name });
			if (!result)
				return ctx.error('UBUS_ERROR', 'ucoord service not available');
			if (!result.ok)
				return ctx.error('FAILED', result.error ?? 'Include not found');

			printf('%.J\n', result.data);
			return ctx.ok();
		}
	},

	set: {
		help: 'Set include file from local JSON file',
		args: [
			{
				name: 'name',
				help: 'Include name',
				type: 'string',
				required: true,
			}
		],
		named_args: {
			file: {
				help: 'Path to JSON file',
				required: true,
				args: { type: 'path' },
			},
		},
		call: function(ctx, argv, named) {
			let venue = ctx.data.venue;
			let name = argv[0];
			let file = named.file;

			let raw = readfile(file);
			if (!raw)
				return ctx.error('NOT_FOUND', `Cannot read file: ${file}`);

			let content = json(raw);
			if (!content)
				return ctx.error('INVALID_JSON', 'Invalid JSON in file');

			let result = ubus.call('ucoord', 'include', { venue, action: 'set', name, content });
			if (!result)
				return ctx.error('UBUS_ERROR', 'ucoord service not available');
			if (!result.ok)
				return ctx.error('FAILED', result.error ?? 'Failed to set include');

			return ctx.ok(`Include '${name}' updated`);
		}
	},

	delete: {
		help: 'Delete an include file',
		args: [
			{
				name: 'name',
				help: 'Include name',
				type: 'string',
				required: true,
			}
		],
		call: function(ctx, argv) {
			let venue = ctx.data.venue;
			let name = argv[0];
			let result = ubus.call('ucoord', 'include', { venue, action: 'delete', name });
			if (!result)
				return ctx.error('UBUS_ERROR', 'ucoord service not available');
			if (!result.ok)
				return ctx.error('FAILED', result.error ?? 'Failed to delete include');

			return ctx.ok(`Include '${name}' deleted`);
		}
	},
};

const ucoord_host_node = {
	status: {
		help: 'Show venue status',
		call: function(ctx, argv) {
			let venue = ctx.data.name;
			let network_name = 'ucoord_' + venue;

			let unetd_config = readjson('/etc/uconfig/data/unetd.json');
			let config = unetd_config.networks?.[network_name];
			if (!config)
				return ctx.error('NOT_FOUND', `Venue '${venue}' not found`);

			printf('Venue:    %s\n', venue);
			printf('Network:  %s\n', network_name);
			printf('Domain:   %s\n', config.domain ?? 'unknown');

			return ctx.ok();
		}
	},

	include: {
		help: 'Manage include files',
		select_node: 'ucoord_include',
		select: function(ctx, argv) {
			return ctx.set('include', { venue: ctx.data.name });
		},
	},

	invite: {
		help: 'Invite a new host to join the network',
		named_args: {
			hostname: {
				help: 'Hostname for the new device',
				required: true,
				args: { type: 'string' },
			},
			'access-key': {
				help: 'Access key (pincode) for the host',
				required: true,
				args: { type: 'string' },
			},
			password: {
				help: 'Network configuration password',
				no_complete: true,
				args: { type: 'string', min: 12 },
			},
			timeout: {
				help: 'Invitation timeout in seconds',
				default: 120,
				args: { type: 'int' },
			},
		},
		call: function(ctx, argv, named) {
			let hostname = named.hostname;

			if (!named.password) {
				named.password = password_get(ctx);
				if (!named.password)
					return;
			}

			let venue = ctx.data.name;
			let network_name = 'ucoord_' + venue;
			let unet = model.context().select(['unet']);
			if (!unet)
				return ctx.error('ERROR', 'unet CLI module not available');

			let edit = unet.select(['edit', network_name]);
			if (!edit)
				return ctx.error('ERROR', `Network '${network_name}' not found`);

			let access_key = named['access-key'];
			let timeout = named['timeout'] ?? 120;
			let ret = edit.call(['invite', hostname, 'access-key', '' + access_key, 'timeout', '' + timeout, 'password', named.password]);
			if (ret?.error)
				return ctx.error('FAILED', ret.error);

			enroll_ctx = edit;
			return ctx.ok(`Invitation sent for host '${hostname}'`);
		}
	},
};

function get_hosts(ctx) {
	let venue = ctx.data.name;
	let network_name = 'ucoord_' + venue;

	let data = ubus.call('unetd', 'network_get', { name: network_name });
	if (!data?.peers)
		return {};

	return data.peers;
}

function remote_callbacks(venue, peer) {
	return {
		commit: function(ctx, config) {
			let result = ubus.call('ucoord', 'configure', { venue, peer, action: 'apply', config });
			if (!result)
				return ctx.error('UBUS_ERROR', 'ucoord service not available');
			if (result.error)
				return ctx.error('UBUS_ERROR', result.error);
			if (!result.ok)
				return ctx.error('FAILED', result.error ?? 'Config apply failed');

			model.uconfig.changed = false;
			model.uconfig.dry_run = false;
			return ctx.ok('Applied');
		},
		dry_run: function(ctx, config) {
			let result = ubus.call('ucoord', 'configure', { venue, peer, action: 'test', config });
			if (!result)
				return ctx.error('UBUS_ERROR', 'ucoord service not available');
			if (result.error)
				return ctx.error('UBUS_ERROR', result.error);
			if (!result.ok)
				return ctx.error('FAILED', 'Config validation failed');

			model.uconfig.dry_run = false;
			return ctx.ok('Passed');
		},
	};
}

function exit_remote_edit_cb() {
	if (model.uconfig.changed) {
		let key = model.poll_key([ 'y', 'n' ], `Pending changes will be lost. Exit anyway ? (y|n) `);
		if (!key)
			key = 'y';

		warn(key + '\n');
		if (key != 'y')
			return false;
	}

	uconfig.pop();
	delete model.uconfig.remote;
	delete model.uconfig.remote_wiphy;
	return true;
}

function remote_edit_select(ctx, venue, peer) {
	let result = ubus.call('ucoord', 'configure', { venue, peer, action: 'get' });

	if (!result)
		return ctx.error('UBUS_ERROR', 'ucoord service not available');
	if (result.error)
		return ctx.error('UBUS_ERROR', result.error);
	if (!result.ok || !result.data)
		return ctx.error('FAILED', 'Failed to fetch remote config');

	let capa = ubus.call('ucoord', 'capabilities', { venue, peer });
	let remote_wiphy;
	if (capa?.ok && capa?.data?.wiphy)
		remote_wiphy = capa.data.wiphy;

	uconfig.push();
	model.uconfig.current_cfg = result.data;
	model.uconfig.changed = false;
	model.uconfig.remote = remote_callbacks(venue, peer);
	model.uconfig.remote_wiphy = remote_wiphy;
	ctx.add_hook('exit', exit_remote_edit_cb);

	return ctx.set(null, {
		object_edit: uconfig.lookup(),
	});
}

function remote_reboot(ctx, venue, peer) {
	let key = model.poll_key([ 'y', 'n' ], `Are you sure ? (y/N) `);
	if (!key)
		key = 'n';

	warn(key + '\n');
	if (key != 'y')
		return;

	let result = ubus.call('ucoord', 'reboot', { venue, peer });

	if (!result)
		return ctx.error('UBUS_ERROR', 'ucoord service not available');
	if (result.error)
		return ctx.error('UBUS_ERROR', result.error);
	if (result.ok)
		return ctx.ok(`Reboot command sent to ${peer}`);

	return ctx.error('FAILED', 'Reboot command failed');
}

function peer_venue_find(peer_name) {
	let result = ubus.call('ucoord', 'status');
	if (!result?.venues)
		return;

	for (let venue, peers in result.venues)
		if (peer_name in peers)
			return venue;
}

const ucoord_host_selected = {
	info: {
		help: 'Show host information',
		call: function(ctx, argv) {
			let name = ctx.data.name;
			let peer = ctx.data.edit;

			printf('Host:       %s\n', name);
			printf('Address:    %s\n', peer.address);
			printf('Connected:  %s\n', peer.connected ? 'yes' : 'no');
			printf('Endpoint:   %s\n', peer.endpoint);
			printf('RX bytes:   %d\n', peer.rx_bytes);
			printf('TX bytes:   %d\n', peer.tx_bytes);
			printf('Idle:       %ds\n', peer.idle);

			return ctx.ok();
		}
	},

	edit: {
		help: 'Edit peer configuration',
		no_subcommands: true,
		select_node: 'ucEdit',
		select: function(ctx, argv) {
			let peer = ctx.data.name;
			let venue = peer_venue_find(peer);
			if (!venue)
				return ctx.error('NOT_FOUND', `Cannot determine venue for peer '${peer}'`);

			return remote_edit_select(ctx, venue, peer);
		},
	},

	reboot: {
		help: 'Reboot the peer',
		call: function(ctx, argv) {
			let peer = ctx.data.name;
			let venue = peer_venue_find(peer);
			if (!venue)
				return ctx.error('NOT_FOUND', `Cannot determine venue for peer '${peer}'`);

			return remote_reboot(ctx, venue, peer);
		}
	},

	sysupgrade: {
		help: 'Upgrade firmware on peer',
		args: [
			{
				name: 'url',
				help: 'Firmware image URL',
				type: 'string',
				required: true,
			}
		],
		call: function(ctx, argv) {
			let peer = ctx.data.name;
			let venue = peer_venue_find(peer);
			if (!venue)
				return ctx.error('NOT_FOUND', `Cannot determine venue for peer '${peer}'`);

			let url = argv[0];

			let key = model.poll_key([ 'y', 'n' ], `Are you sure ? (y/N) `);
			if (!key)
				key = 'n';

			warn(key + '\n');
			if (key != 'y')
				return;

			let result = ubus.call('ucoord', 'sysupgrade', { venue, peer, url, action: 'apply', timeout: 120000 });

			if (!result)
				return ctx.error('UBUS_ERROR', 'ucoord service not available');
			if (result.error)
				return ctx.error('UBUS_ERROR', result.error);
			if (result.ok)
				return ctx.ok(`Sysupgrade command sent to ${peer}`);

			return ctx.error('FAILED', 'Sysupgrade command failed');
		}
	},
};

const host_edit_create_destroy = {
	types: {
		host: {
			node_name: 'ucoord_host_selected',
			node: ucoord_host_selected,
			get_object: (ctx, type_name) => get_hosts(ctx),
			delete: function(ctx, type_name, name) {
				let password = password_get(ctx);
				if (!password)
					return false;

				let venue = ctx.data.name;
				let network_name = 'ucoord_' + venue;
				let unet = model.context().select(['unet']);
				if (!unet) {
					ctx.error('ERROR', 'unet CLI module not available');
					return false;
				}

				let edit = unet.select(['edit', network_name]);
				if (!edit) {
					ctx.error('ERROR', `Network '${network_name}' not found`);
					return false;
				}

				let ret = edit.call(['destroy', 'host', name]);
				if (ret?.error) {
					ctx.error('FAILED', ret.error);
					return false;
				}

				ret = edit.call(['apply', 'password', password]);
				if (ret?.error) {
					ctx.error('FAILED', ret.error);
					return false;
				}
				return true;
			},
		},
	},
};

function ucoord_host_node_get() {
	let node = { ...ucoord_host_node };
	editor.edit_create_destroy(host_edit_create_destroy, node);
	delete node.create;

	node.list = {
		...node.list,
		call: function(ctx, argv) {
			let venue = ctx.data.name;
			let result = ubus.call('ucoord', 'status');
			let peers = result?.venues?.[venue];
			if (!peers)
				return ctx.ok('No hosts found');

			let data = [];
			for (let name, info in peers)
				push(data, [ name, info.state ?? 'unknown' ]);

			return ctx.table('Hosts', data);
		},
	};

	return node;
}

const venue_edit_create_destroy = {
	named_args: {
		network: {
			help: 'Network interface for unet service',
			required: true,
			args: {
				type: 'enum',
				value: () => active_config_interfaces(),
			},
		},
		password: {
			help: 'Network configuration password',
			no_complete: true,
			args: { type: 'string', min: 12 },
		},
	},
	types: {
		venue: {
			node_name: 'ucoord_host_node',
			node: ucoord_host_node,
			get_object: (ctx, type_name) => get_venues(),
			add: function(ctx, type_name, name, named) {
				if (length(name) > 8) {
					ctx.invalid_argument('Venue name must be at most 8 characters');
					return;
				}

				if (!named.password) {
					named.password = password_get(ctx, 'Set new config password: ', true);
					if (!named.password)
						return;
				}

				if (!unet_service_inject(named.network)) {
					ctx.error('ERROR', `Interface '${named.network}' not found in active config`);
					return;
				}

				let network_name = 'ucoord_' + name;
				let unet = model.context().select(['unet']);
				if (!unet) {
					ctx.error('ERROR', 'unet CLI module not available');
					return;
				}

				let ret = unet.call(['create', 'network', network_name, 'password', named.password]);
				if (ret?.error) {
					ctx.error('FAILED', ret.error);
					return;
				}

				ubus.call('ucoord', 'reload');
				return {};
			},
			insert: (ctx, type_name, name, data, named) => true,
			delete: function(ctx, type_name, name) {
				let password = password_get(ctx);
				if (!password)
					return false;

				let network_name = 'ucoord_' + name;
				let unet = model.context().select(['unet']);
				if (!unet) {
					ctx.error('ERROR', 'unet CLI module not available');
					return false;
				}

				let ret = unet.call(['delete', network_name, 'password', password]);
				if (ret?.error) {
					ctx.error('FAILED', ret.error);
					return false;
				}
				return true;
			},
		},
	},
};

function ucoord_node_get() {
	let node = { ...ucoord_node };
	editor.edit_create_destroy(venue_edit_create_destroy, node);

	let result = ubus.call('ucoord', 'status');
	let venues = result?.venues;
	if (venues)
		for (let venue_name, peers in venues)
			for (let peer_name in keys(peers))
				node[peer_name] ??= host_select(peer_name, venue_name);

	return node;
}

const ucoord_host = {
	info: {
		help: 'Show peer information',
		call: function(ctx, argv) {
			let venue = ctx.data.venue;
			let peer = ctx.data.host;
			let result = ubus.call('ucoord', 'info', { venue, peer });

			if (!result)
				return ctx.error('UBUS_ERROR', 'ucoord service not available');
			if (result.error)
				return ctx.error('UBUS_ERROR', result.error);
			if (!result.ok)
				return ctx.error('FAILED', 'Info request failed');

			let info = result.data ?? {};
			printf('Uptime:       %s\n', info.uptime ? format_duration(info.uptime) : 'unknown');

			if (info.memory)
				printf('Memory:       %s / %s (%.1f%% free)\n',
					format_bytes(info.memory.free),
					format_bytes(info.memory.total),
					(info.memory.free / info.memory.total) * 100);

			return ctx.ok();
		}
	},

	state: {
		help: 'Show peer state (ports, radios)',
		call: function(ctx, argv) {
			let venue = ctx.data.venue;
			let peer = ctx.data.host;
			let result = ubus.call('ucoord', 'state', { venue, peer });

			if (!result)
				return ctx.error('UBUS_ERROR', 'ucoord service not available');
			if (result.error)
				return ctx.error('UBUS_ERROR', result.error);

			let state = result.state;

			if (state?.ports && length(state.ports)) {
				printf('Ports:\n');
				for (let port in state.ports)
					printf('  %s: %s\n', port.name ?? 'unknown', port.link ? 'up' : 'down');
			}

			if (state?.radios && length(state.radios)) {
				printf('Radios:\n');
				for (let radio in state.radios)
					printf('  %s: ch%d %s\n',
						radio.name ?? 'unknown',
						radio.channel ?? 0,
						radio.band ?? 'unknown');
			}

			return ctx.ok();
		}
	},

	config: {
		help: 'Configuration management',
		select_node: 'ucoord_config',
		select: function(ctx, argv) {
			return ctx.set('config', ctx.data);
		},
	},

	edit: {
		help: 'Edit peer configuration',
		no_subcommands: true,
		select_node: 'ucEdit',
		select: function(ctx, argv) {
			return remote_edit_select(ctx, ctx.data.venue, ctx.data.host);
		},
	},

	reboot: {
		help: 'Reboot the peer',
		call: function(ctx, argv) {
			return remote_reboot(ctx, ctx.data.venue, ctx.data.host);
		}
	},

	sysupgrade: {
		help: 'Upgrade firmware on peer',
		args: [
			{
				name: 'url',
				help: 'Firmware image URL',
				type: 'string',
				required: true,
			}
		],
		call: function(ctx, argv) {
			let venue = ctx.data.venue;
			let peer = ctx.data.host;
			let url = argv[0];

			let key = model.poll_key([ 'y', 'n' ], `Are you sure ? (y/N) `);
			if (!key)
				key = 'n';

			warn(key + '\n');
			if (key != 'y')
				return;

			let result = ubus.call('ucoord', 'sysupgrade', { venue, peer, url, action: 'apply', timeout: 120000 });

			if (!result)
				return ctx.error('UBUS_ERROR', 'ucoord service not available');
			if (result.error)
				return ctx.error('UBUS_ERROR', result.error);
			if (result.ok)
				return ctx.ok(`Sysupgrade command sent to ${peer}`);

			return ctx.error('FAILED', 'Sysupgrade command failed');
		}
	},
};

const ucoord_config = {
	status: {
		help: 'Show configuration status',
		call: function(ctx, argv) {
			let venue = ctx.data.venue;
			let peer = ctx.data.host;
			let result = ubus.call('ucoord', 'configure', { venue, peer, action: 'get' });

			if (!result)
				return ctx.error('UBUS_ERROR', 'ucoord service not available');
			if (result.error)
				return ctx.error('UBUS_ERROR', result.error);
			if (!result.ok)
				return ctx.error('FAILED', 'Config status request failed');

			printf('%.J\n', result.data);
			return ctx.ok();
		}
	},

	validate: {
		help: 'Validate configuration on peer',
		args: [
			{
				name: 'file',
				help: 'Configuration file path',
				type: 'path',
				required: true,
			}
		],
		call: function(ctx, argv) {
			let venue = ctx.data.venue;
			let peer = ctx.data.host;
			let file = argv[0];

			let content = readfile(file);
			if (!content)
				return ctx.error('NOT_FOUND', `Cannot read file: ${file}`);

			let config = json(content);
			if (!config)
				return ctx.error('INVALID_JSON', 'Invalid JSON in config file');

			let result = ubus.call('ucoord', 'configure', { venue, peer, action: 'test', config });

			if (!result)
				return ctx.error('UBUS_ERROR', 'ucoord service not available');
			if (result.error)
				return ctx.error('UBUS_ERROR', result.error);
			if (!result.ok)
				return ctx.error('FAILED', 'Config validation failed');

			return ctx.ok('Configuration is valid');
		}
	},

	push: {
		help: 'Push and apply configuration to peer',
		args: [
			{
				name: 'file',
				help: 'Configuration file path',
				type: 'path',
				required: true,
			}
		],
		call: function(ctx, argv) {
			let venue = ctx.data.venue;
			let peer = ctx.data.host;
			let file = argv[0];

			let content = readfile(file);
			if (!content)
				return ctx.error('NOT_FOUND', `Cannot read file: ${file}`);

			let config = json(content);
			if (!config)
				return ctx.error('INVALID_JSON', 'Invalid JSON in config file');

			let result = ubus.call('ucoord', 'configure', { venue, peer, action: 'apply', config });

			if (!result)
				return ctx.error('UBUS_ERROR', 'ucoord service not available');
			if (result.error)
				return ctx.error('UBUS_ERROR', result.error);
			if (!result.ok)
				return ctx.error('FAILED', result.error ?? 'Config apply failed');

			return ctx.ok('Configuration applied');
		}
	},
};

const Root = {
	ucoord: {
		help: 'Mesh coordination management',
		select_node: 'ucoord',
	}
};

model.add_nodes({
	Root,
	ucoord: ucoord_node_get(),
	ucoord_host,
	ucoord_config,
	ucoord_include,
	ucoord_host_node: ucoord_host_node_get(),
	ucoord_host_selected,
});
