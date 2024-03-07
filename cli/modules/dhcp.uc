import * as uconfig from 'cli.uconfig';
import * as editor from 'cli.object-editor';
import { readfile, writefile } from 'fs';

let config = json(readfile('/etc/uconfig/data/dhcp.json') || '{}');
config.lan ??= {};
config.wan ??= {};
model.dhcp = { };

const dhcp_lease_editor = {
	change_cb: () => model.dhcp.changed = true,

	named_args: {
		network: {
			help: 'The network that the lease is active on',
			required: true,
			get: function(ctx) {
				for (let net, data in config)
					if (ctx.data.name in data)
						return net;
			},
			set: function(ctx, val) {
				let name = ctx.data.name;
				let dest = config[val];
				if (!dest)
					return ctx.invalid_argument();
				for (let net, data in config)
					delete data[name];
				dest[name] = ctx.data.edit;
			},
			args: {
				type: 'enum',
				value: () => keys(config),
			}
		},
		macaddr: {
			help: 'The MAC address of the host that this lease shall be used for',
			required: true,
			args: {
				type: 'macaddr',
			}
		},

		'lease-offset': {
			help: 'The offset of the IP that shall be used in relation to the first IP in the available range',
			required: true,
			args: {
				type: 'int',
			}
		},

		'lease-time': {
			help: 'How long the lease is valid before a RENEW must be issued',
			required: true,
			args: {
				type: 'string',
				format: 'hours',
			}
		},

		'publish-hostname': {
			help: 'Shall the hosts hostname be made available locally via DNS',
			required: true,
			default: true,
			args: {
				type: 'bool',
			}
		},
	}
};
const dhcp_lease = model.add_node('dhcp_lease', editor.new(dhcp_lease_editor));

const dhcp_leases_edit_create_destroy = {
	change_cb: () => model.dhcp.changed = true,

	type: {
		name: 'lease',
		node_name: 'dhcp_lease',
		node: dhcp_lease,
		get_object: function(ctx) {
			let data = {};
			for (let net, val in config)
				data = { ...data, ...val };
			return data;
		},
		insert: function(ctx, type, name, data, named) {
			let dest = config[named.network];
			if (!dest)
				return;

			dest[name] = data;
			return true;
		},
		delete: function(ctx, type, name) {
			for (let net, data in config)
				delete data[name];
			return true;
		}
	}
};


const dhcp_leases = {
	commit: {
		help: 'Store and apply pending changes',
		call: function(ctx, argv) {
			model.dhcp.changed = false;
			writefile('/etc/uconfig/data/dhcp.json', config);
			return ctx.ok('Done');
		},
	}
};

editor.edit_create_destroy(dhcp_leases_edit_create_destroy, dhcp_leases);
model.add_node('dhcp_leases', dhcp_leases);

function exit_dhcp_cb() {
	if (!model.dhcp.changed)
		return true;

	warn(`Pending changes will be lost. Exit anyway ? (y|n) `);
	while (1) {
		key = lc(model.cb.poll_key());
		if (key == null || key == 'y')
			return true;
		if (key == 'n')
			return false;
	}
	warn(key + '\n');
}

const Root = {
	dhcp: {
		help: 'Configure the local dhcp leases',
		no_subcommands: true,
		select_node: 'dhcp_leases',
		select: function(ctx, argv) {
			return ctx.set(null, {
				object_edit: config,
			});
		},
	}
};
model.add_node('Root', Root);
