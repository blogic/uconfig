import * as uconfig from 'cli.uconfig';
import * as editor from "cli.object-editor";

const auth_editor = {
	change_cb: uconfig.changed,

	named_args: {
		host: {
			help: 'The URI of the authentication server',
			required: true,
			args: {
				type: 'host',
			}
		},

		port: {
			help: 'The network port of the authentication server',
			default: '1812',
			args: {
				type: 'int',
				min: 1,
				max: 65535,
			}
		},

		secret: {
			help: 'The shared Radius authentication secret',
			default: 'secret',
			args: {
				type: 'string',
			}
			
		},
	}
};

const acct_editor = {
	change_cb: uconfig.changed,

	named_args: {
		host: {
			help: 'The URI of the accounting server',
			required: true,
			args: {
				type: 'host',
			}
		},

		port: {
			help: 'The network port of the accounting server',
			default: '1812',
			args: {
				type: 'int',
				min: 1,
				max: 65535,
			}
		},

		secret: {
			help: 'The shared Radius accounting secret',
			default: 'secret',
			args: {
				type: 'string',
			}
			
		},

		interval: {
			help: 'The interim accounting update interval',
			default: 60,
			args: {
				type: 'int',
				min: 60
			}
		},
	}
};
	
const radius_editor = {
	change_cb: uconfig.changed,

	named_args: {
		'nas-identifier': {
			help: 'NAS-Identifier string for RADIUS messages',
			args: {
				type: 'string',
			}
		},
	},
};

uconfig.add_node('ucRadiusAuthentication', editor.new(auth_editor));
uconfig.add_node('ucRadiusAccounting', editor.new(acct_editor));

const ucRadiusServer = {
	authentication: {
		select_node: 'ucRadiusAuthentication',
		select: function(ctx, argv) {
			return ctx.set(null, {
				edit: uconfig.lookup([ 'configurations', 'radius-servers', ctx.data.name, 'authentication' ]),
			});
		}
	},

	accounting: {
		select_node: 'ucRadiusAccounting',
		select: function(ctx, argv) {
			return ctx.set(null, {
				edit: uconfig.lookup([ 'configurations', 'radius-servers', ctx.data.name, 'accounting' ]),
			});
		}
	},
};
editor.new(radius_editor, ucRadiusServer);
uconfig.add_node('ucRadiusServer', ucRadiusServer);

const configurations_editor = {
	change_cb: uconfig.changed,

	named_args: {
		'ipv4-network': {
			help: 'Define the IPv4 range that can be used by downstream interfaces',
			args: {
				type: 'cidr4',
			}
		},

		'ipv6-network': {
			help: 'Define the IPv6 range that can be used by downstream interfaces',
			args: {
				type: 'cidr6',
			}
		},

		'ntp-servers': {
			help: "Define which NTP servers shall be used.",
			multiple: true,
			args: {
				type: 'ipv4',
			}
		},

	},
};

const edit_create_destroy = {
	change_cb: uconfig.changed,
	
	types: {
		radius: {
			node_name: 'ucRadiusServer',
			node: ucRadiusServer,
			object: 'radius-servers',
			add: (ctx, type, name) => { return {}; }
		},
	},
};

const ucConfigurations = { };
editor.new(configurations_editor, ucConfigurations);
editor.edit_create_destroy(edit_create_destroy, ucConfigurations);
uconfig.add_node('ucConfigurations', ucConfigurations);

const ucEdit = {
	configurations: {
		help: 'Manage global configurations on the device',
		select_node: 'ucConfigurations',
		select: function(ctx, argv) {
			return ctx.set(null, { 
				edit: uconfig.lookup([ 'configurations' ]),
				object_edit: uconfig.lookup([ 'configurations' ]),
			});
		},
	},
};
uconfig.add_node('ucEdit', ucEdit);
