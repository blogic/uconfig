import * as uconfig from 'cli.uconfig';
import * as editor from 'cli.object-editor';

function is_proto_static(ctx, args, named) {
	let addressing = named.addressing;
	if (ctx.data.edit)
		addressing ??= ctx.data.edit.addressing;
	return addressing == 'static';
}

const dhcp_pool_editor = {
	change_cb: uconfig.changed,

	named_args: {
		'lease-first': {
			help: 'The last octet of the first IPv4 address in this DHCP pool',
			default: '10',
			required: true,
			args: {
				type: 'int',
				min: 1,
			}
		},

		'lease-count': {
			help: 'The number of IPv4 addresses inside the DHCP pool',
			default: '200',
			required: true,
			args: {
				type: 'int',
				min: 10,
			}
		},

		'lease-time': {
			help: 'How long the lease is valid before a RENEW must be issued',
			default: '6h',
			required: true,
			args: {
				type: 'string',
				format: 'hours',
			}
			
		},
	}
};
const ucDHCPPool = uconfig.add_node('ucDHCPPool', editor.new(dhcp_pool_editor));

const dhcp_lease_editor = {
        change_cb: uconfig.changed,

	named_args: {
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
			help: 'How long the lease is valid before a RENEW muss ne issued',
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
const ucDHCPLease = uconfig.add_node('ucDHCPLease', editor.new(dhcp_lease_editor));

const dhcp_leases_edit_create_destroy = {
        change_cb: uconfig.changed,
	
	types: {
		'dhcp-lease': {
			node_name: 'ucDHCPLease',
			node: ucDHCPLease,
			object: 'dhcp-leases',
		},
	},
};

const ipv4_editor = {
        change_cb: uconfig.changed,

	named_args: {
		addressing: {
			help: 'This option defines the method by which the IPv4 address of the interface is chosen',
			default: 'none',
			required: true,
			args: {
				type: 'enum',
				value: [ 'none', 'static', 'dynamic'],
			}
		},

		subnet: {
			help: 'This option defines the static IPv4 of the logical interface in CIDR notation',
			available: is_proto_static,
			args: {
				type: 'cidr4',
				allow_auto: true,
			}
		},

		gateway: {
			help: 'This option defines the static IPv4 gateway of the logical interface',
			available: is_proto_static,
			args: {
				type: 'ipv4',
			}
			
		},

		'dns-servers': {
			help: "Define which DNS servers shall be used.",
			multiple: true,
			attribute: 'use-dns',
			available: is_proto_static,
			args: {
				type: 'ipv4',
			}
		},
	}
};

const ucIPv4 = {
	'dhcp-pool': {
		select_node: 'ucDHCPPool',
		select: function(ctx, argv) {
			return ctx.set(null, {
				edit: uconfig.lookup([ 'interfaces', ctx.data.name, 'ipv4', 'dhcp-pool' ]),
			});
		}
	},
};
editor.new(ipv4_editor, ucIPv4);
editor.edit_create_destroy(dhcp_leases_edit_create_destroy, ucIPv4);
uconfig.add_node('ucIPv4', ucIPv4);

const interface_editor = {
        change_cb: uconfig.changed,

	named_args: {
		role: {
			help: 'The role defines if the interface is upstream or downstream facing',
			default: 'downstream',
			required: true,
			args: {
				type: 'enum',
				value: [ 'upstream', 'downstream'],
			}
		},

		'vlan-id': {
			help: 'The VLAN Id assigned to the interface',
			attribute: 'id',
			get_object: (ctx, param, obj, argv) => {
				obj.vlan ??= {};
				return obj.vlan;
			},
			args: {
				type: 'int',
				min: 1,
				max: 4095,
			}
		},
		
		'vlan-trunks': {
			help: 'Upstream interfaces can prOvide NAT for downstream interfaces that have a different VLAN Id',
			attribute: 'trunks',
			get_object: (ctx, param, obj, argv) => {
				obj.vlan ??= {};
				return obj.vlan;
			},
			multiple: true,
			args: {
				type: 'int',
				min: 1,
				max: 4095,
			}
		},

		service: {
			help: 'The services that shall be offered on this logical interface',
			multiple: true,
			attribute: 'services',
			args: {
				type: 'enum',
				value: () => model.uconfig.services,
			}
		},

		port: {
			help: '',
			multiple: true,
			attribute: 'ports',
			set: (ctx, val) => {
				ctx.data.edit.ports = {};
				for (let k in val)
					ctx.data.edit.ports[k] = 'auto';
			},
			get: (ctx) => sort(keys(ctx.data.edit.ports || {})),
			add: (ctx, val) =>  {
				for (let k in val)
					ctx.data.edit.ports[k] = 'auto';
			},
			remove: (ctx, val) => {
				let ports = sort(keys(ctx.data.edit.ports || {}));
				delete ctx.data.edit.ports[ports[val - 1]];
			},
			args: {
				type: 'enum',
				value: [ 'lan*', 'lan1' ],
			}
		},
		
	}
};

function is_psk_required(ctx, args, named) {
	let template = named.template || ctx.data.edit?.template;
	return template in [ 'encrypted', 'manual', 'batman' ];
} 

function is_radius_required(ctx, args, named) {
	let template = named.template || ctx.data.edit?.template;
	return template in [ 'enterprise' ];
} 

function is_ap_mode(ctx, args, named) {
	let bss_mode = named['bss-mode'] || ctx.data.edit?.['bss-mode'] || 'ap';
	return bss_mode == 'ap';
} 

function get_encryption_object(ctx, param, obj, argv) {
	obj.encryption ??= {};
	return obj.encryption;
}

const ssid_editor = {
        change_cb: uconfig.changed,

	named_args: {
		template: {
			help: 'The configuration/behaviour template used by the BSS',
			default: 'encrypted',
			required: true,
			args: {
				type: 'enum',
				value: [ 'open', 'manual', 'encrypted', 'enterprise', 'batman', 'opportunistic' ],
			}
		},

		security: {
			help: 'The encryption strength used by this BSS',
			default: 'maximum',
			required: true,
			args: {
				type: 'enum',
				value: [ 'compatibility', 'maximum', ],
			}
		},

		'bss-mode': {
			help: 'Selects the operation mode of the wireless network interface controller',
			default: 'ap',
			required: true,
			args: {
				type: 'enum',
				value: [ 'ap', 'sta', 'wds-ap', 'wds-sta', 'wds-repeater' ],
			}
		},

		ssid: {
			help: 'The broadcasted SSID of the wireless network and for for managed mode the SSID of the network you’re connecting to',
			required: true,
			default: 'OpenWrt',
			args: {
				type: 'string',
				min: 1,
				max: 32,
			}
		},
		
		key: {
			help: 'The Pre Shared Key (PSK) that is used for encryption on the BSS',
			required: true,
			available: is_psk_required,
			get_object: get_encryption_object,
			args: {
				type: 'string',
				min: 8,
				max: 63,
			}
		},

		'radius-server': {
			help: 'The Pre Shared Key (PSK) that is used for encryption on the BSS',
			required: true,
			available: is_radius_required,
			get_object: get_encryption_object,
			args: {
				type: 'enum',
				value: function() {
					return sort(keys(uconfig.lookup([ 'configurations', 'radius-servers' ])));
				},
			}
		},

		'radio': {
			help: 'The list of radios hat the SSID should be broadcasted on. The configuration layer will use the first matching phy/band',
			multiple: true,
			allow_duplicate: false,
			attribute: 'wifi-radios',
			required: true,
			default: () => model.uconfig.bands,
			args: {
				type: 'enum',
				value: () => model.uconfig.bands,
			}
		},

		hidden: {
			help: 'Disables the broadcasting of the ESSID inside beacon frames',
			attribute: 'hidden-ssid',
			available: is_ap_mode,
			default: false,
			args: {
				type: 'bool',
			}
		},

		roaming: {
			help: 'Enable 802.11r Fast Roaming for this BSS.',
			default: true,
			available: is_ap_mode,
			args: {
				type: 'bool',
			}
		},

		'isolate-clients': {
			help: 'Isolates wireless clients from each other on this BSS',
			available: is_ap_mode,
			default: false,
			args: {
				type: 'bool'
			}
		},

		'rate-limit-ingress': {
			help: 'The ingress rate to which hosts will be shaped. Values are in Mbps',
			attribute: 'ingress-rate',
			available: is_ap_mode,
			get_object: (ctx, param, obj, argv) => {
				obj['rate-limit'] ??= {};
				return obj['rate-limit'];
			},
			args: {
				type: 'int',
			}
		},

		'rate-limit-egress': {
			help: 'The egress rate to which hosts will be shaped. Values are in Mbps',
			attribute: 'egress-rate',
			available: is_ap_mode,
			get_object: (ctx, param, obj, argv) => {
				obj['rate-limit'] ??= {};
				return obj['rate-limit'];
			},
			args: {
				type: 'int',
			}
		},
	}
};
const ucSSID = uconfig.add_node('ucSSID', editor.new(ssid_editor));

const interface_edit_create_destroy = {
        change_cb: uconfig.changed,

	types: {
		ssid: {
			node_name: 'ucSSID',
			node: ucSSID,
			object: 'ssids',
		},
	},
};

const ucInterface = {
	ipv4: {
		select_node: 'ucIPv4',
		select: function(ctx, argv) {
			return ctx.set(null, {
				edit : uconfig.lookup([ 'interfaces', ctx.data.name, 'ipv4' ]),
				object_edit: uconfig.lookup([ 'interfaces', ctx.data.name, 'ipv4' ]),
			});
		}
	},
};
editor.new(interface_editor, ucInterface);
editor.edit_create_destroy(interface_edit_create_destroy, ucInterface);
uconfig.add_node('ucInterface', ucInterface);

const edit_create_destroy = {
        change_cb: uconfig.changed,
	
	types: {
		interface: {
			node_name: 'ucInterface',
			node: ucInterface,
			object: 'interfaces',
			add: (ctx, type, name) => {
				return {
					'role': 'downstream'
				};
			},
		},
	},
};
uconfig.add_node('ucEdit', editor.edit_create_destroy(edit_create_destroy));
