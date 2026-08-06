'use strict';

import { access } from 'fs';
import * as uconfig from 'cli.uconfig';
import * as editor from 'cli.object-editor';

const has_wwan = access('/lib/apk/packages/ucode-mod-wwan.list');

function is_proto_static(ctx, args, named) {
	let addressing = named.addressing;
	if (ctx.data.edit?.addressing)
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

		'use-dns': {
			help: 'DNS servers to announce via DHCP option 6',
			multiple: true,
			args: {
				type: 'ipv4',
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
				value: [ 'none', 'static', 'dynamic' ],
			}
		},

		subnet: {
			help: 'This option defines the static IPv4 of the logical interface in CIDR notation',
//			available: is_proto_static,
			args: {
				type: 'cidr4',
				allow_auto: true,
			}
		},

		gateway: {
			help: 'This option defines the static IPv4 gateway of the logical interface',
//			available: is_proto_static,
			args: {
				type: 'ipv4',
			}
			
		},

		'dns-servers': {
			help: "Define which DNS servers shall be used.",
			multiple: true,
			attribute: 'use-dns',
//			available: is_proto_static,
			args: {
				type: 'ipv4',
			}
		},

		'send-hostname': {
			help: 'Include the devices hostname inside DHCP requests',
			default: true,
			args: {
				type: 'bool',
			}
		},

		'disallow-upstream-subnet': {
			help: 'Block traffic to specified subnets on downstream interfaces (true blocks all RFC1918)',
			multiple: true,
			args: {
				type: 'cidr4',
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

const dhcpv6_editor = {
	change_cb: uconfig.changed,

	named_args: {
		'mode': {
			help: 'DHCPv6 operation mode',
			default: 'hybrid',
			required: true,
			args: {
				type: 'enum',
				value: [ 'hybrid', 'stateless', 'stateful', 'relay' ],
			}
		},

		'announce-dns': {
			help: 'DNS servers to announce via DHCPv6',
			multiple: true,
			args: {
				type: 'ipv6',
			}
		},

		'filter-prefix': {
			help: 'IPv6 prefix filter for downstream prefix selection',
			default: '::/0',
			args: {
				type: 'cidr6',
			}
		},
	}
};
const ucDHCPv6 = uconfig.add_node('ucDHCPv6', editor.new(dhcpv6_editor));

const ipv6_editor = {
	change_cb: uconfig.changed,

	named_args: {
		'addressing': {
			help: 'IPv6 addressing mode',
			default: 'dynamic',
			required: true,
			args: {
				type: 'enum',
				value: [ 'dynamic', 'static' ],
			}
		},

		'subnet': {
			help: 'Static IPv6 address in CIDR notation (use auto/64 for automatic allocation)',
			args: {
				type: 'cidr6',
			}
		},

		'gateway': {
			help: 'Static IPv6 gateway address',
			args: {
				type: 'ipv6',
			}
		},

		'prefix-size': {
			help: 'IPv6 prefix size to request or allocate (0-64)',
			args: {
				type: 'int',
				min: 0,
				max: 64,
			}
		},
	}
};

const ucIPv6 = {
	'dhcpv6': {
		help: 'Configure DHCPv6 server settings',
		select_node: 'ucDHCPv6',
		select: function(ctx, argv) {
			return ctx.set(null, {
				edit: uconfig.lookup([ 'interfaces', ctx.data.name, 'ipv6', 'dhcpv6' ]),
			});
		}
	},
};
editor.new(ipv6_editor, ucIPv6);
uconfig.add_node('ucIPv6', ucIPv6);

function is_wwan_type(ctx, args, named) {
	let bb_type = named.type;
	if (ctx.data.edit?.type)
		bb_type ??= ctx.data.edit.type;
	return bb_type == 'wwan';
}

function is_pppoe_type(ctx, args, named) {
	let bb_type = named.type;
	if (ctx.data.edit?.type)
		bb_type ??= ctx.data.edit.type;
	return bb_type == 'pppoe';
}

const broad_band_editor = {
	change_cb: uconfig.changed,

	named_args: {
		type: {
			help: 'Broadband connection type',
			args: {
				type: 'enum',
				value: function() {
					let values = [ 'pppoe' ];
					if (has_wwan)
						push(values, 'wwan');
					return values;
				},
			}
		},

		username: {
			help: 'Authentication username for the broadband connection',
			args: {
				type: 'string',
			}
		},

		password: {
			help: 'Authentication password for the broadband connection',
			args: {
				type: 'string',
			}
		},

		device: {
			help: 'Modem control device path for WWAN connections',
			available: is_wwan_type,
			default: '/dev/cdc-wdm0',
			args: {
				type: 'string',
			}
		},

		apn: {
			help: 'Access point name for cellular connections',
			available: is_wwan_type,
			args: {
				type: 'string',
			}
		},

		pincode: {
			help: 'SIM card PIN code',
			available: is_wwan_type,
			args: {
				type: 'string',
			}
		},

		'ip-type': {
			help: 'IP version negotiated by the modem',
			available: is_wwan_type,
			default: 'ipv4v6',
			args: {
				type: 'enum',
				value: [ 'ipv4', 'ipv6', 'ipv4v6' ],
			}
		},

		'service-name': {
			help: 'PPPoE service name filter',
			available: is_pppoe_type,
			args: {
				type: 'string',
			}
		},

		'ac-name': {
			help: 'PPPoE access concentrator name filter',
			available: is_pppoe_type,
			args: {
				type: 'string',
			}
		},
	}
};
const ucBroadBand = uconfig.add_node('ucBroadBand', editor.new(broad_band_editor));

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

		disable: {
			help: 'Do not bring this interface up when applying the config.',
			default: false,
			args: {
				type: 'bool',
			}
		},

		'isolate-hosts': {
			help: 'Isolate traffic and block local IP ranges (guest network mode)',
			default: false,
			args: {
				type: 'bool',
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
				max: 4094,
			}
		},
		
		'vlan-trunks': {
			help: 'Upstream interfaces can provide NAT for downstream interfaces that have a different VLAN Id',
			attribute: 'trunks',
			get_object: (ctx, param, obj, argv) => {
				obj.vlan ??= {};
				return obj.vlan;
			},
			multiple: true,
			args: {
				type: 'int',
				min: 1,
				max: 4094,
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
			help: 'The physical network ports assigned to this interface',
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
				if (val >= 1 && val <= length(ports))
					delete ctx.data.edit.ports[ports[val - 1]];
			},
			args: {
				type: 'enum',
				value: [ 'lan*', 'lan1' ],
			}
		},
		
	}
};

const multi_psk_editor = {
        change_cb: uconfig.changed,

	named_args: {
		key: {
			help: 'The Pre Shared Key (PSK) for this user',
			required: true,
			args: {
				type: 'string',
				min: 8,
				max: 63,
			}
		},

		macaddr: {
			help: 'The MAC address of the host that this lease shall be used for',
			attribute: 'mac',
			multiple: true,
			allow_duplicate: false,
			args: {
				type: 'macaddr',
			}
		},

		'vlan-id': {
			help: 'The VLAN Id assigned to the interface',
			args: {
				type: 'int',
				min: 1,
				max: 4094,
			}
		},
	}
};
const ucMPSK = uconfig.add_node('ucMPSK', editor.new(multi_psk_editor));

function is_ap_mode(ctx, args, named) {
	let bss_mode = named['bss-mode'] || ctx.data.edit?.['bss-mode'] || 'ap';
	return bss_mode == 'ap';
}

function is_security_available(ctx, args, named) {
	let mode = named.mode || ctx.data.edit?.template?.mode;
	return mode == 'encrypted' || mode == 'enterprise' || mode == 'opportunistic';
}

function is_key_required(ctx, args, named) {
	let mode = named.mode || ctx.data.edit?.template?.mode;
	return mode == 'encrypted' || mode == 'batman-adv';
}

function is_radius_required(ctx, args, named) {
	let mode = named.mode || ctx.data.edit?.template?.mode;
	return mode == 'enterprise';
}

function get_template_object(ctx, param, obj, argv) {
	obj.template ??= {};
	return obj.template;
}

const ssid_editor = {
	change_cb: uconfig.changed,

	named_args: {
		mode: {
			help: 'The configuration/behaviour template used by the BSS',
			default: 'encrypted',
			required: true,
			get_object: get_template_object,
			args: {
				type: 'enum',
				value: [ 'open', 'encrypted', 'enterprise', 'opportunistic', 'batman-adv' ],
			}
		},

		security: {
			help: 'The encryption strength used by this BSS',
			default: 'maximum',
			available: is_security_available,
			get_object: get_template_object,
			args: {
				type: 'enum',
				value: [ 'legacy', 'compatibility', 'maximum' ],
			}
		},

		key: {
			help: 'The Pre Shared Key (PSK) for encryption',
			required: true,
			available: is_key_required,
			get_object: get_template_object,
			args: {
				type: 'string',
				min: 8,
				max: 63,
			}
		},

		'radius-server': {
			help: 'The RADIUS server name (use "local" for built-in server)',
			required: true,
			default: 'local',
			available: is_radius_required,
			get_object: get_template_object,
			args: {
				type: 'enum',
				value: function() {
					let servers = sort(keys(uconfig.lookup([ 'definitions', 'radius-servers' ]) || {}));
					unshift(servers, 'local');
					return servers;
				},
			}
		},

		'bss-mode': {
			help: 'Selects the operation mode of the wireless network interface controller',
			default: 'ap',
			required: true,
			args: {
				type: 'enum',
				value: [ 'ap', 'sta', 'mesh', 'wds-ap', 'wds-sta', 'wds-repeater' ],
			}
		},

		ssid: {
			help: 'The broadcasted SSID of the wireless network',
			required: true,
			default: 'OpenWrt',
			args: {
				type: 'string',
				min: 1,
				max: 32,
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

		disable: {
			help: 'Do not bring up this SSID when applying the config.',
			default: false,
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

		'rate-limit': {
			help: 'The rate to which hosts will be shaped. Value is in Mbps',
			available: is_ap_mode,
			args: {
				type: 'int',
			}
		},
	/*	'rate-limit-ingress': {
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
	*/
	}
};

const ssid_edit_create_destroy = {
        change_cb: uconfig.changed,

	types: {
		'multi-psk': {
			node_name: 'ucMPSK',
			node: ucMPSK,
			object: 'multi-psk',
		},
	},
};

function is_multi_psk_available(ctx) {
	let mode = ctx.data.edit?.template?.mode;
	let security = ctx.data.edit?.template?.security;
	return mode == 'encrypted' && security == 'legacy';
}

const ucSSID = {};
editor.new(ssid_editor, ucSSID);
editor.edit_create_destroy(ssid_edit_create_destroy, ucSSID);
for (let cmd in ['create', 'list', 'destroy', 'multi-psk'])
	if (ucSSID[cmd])
		ucSSID[cmd].available = is_multi_psk_available;
uconfig.add_node('ucSSID', ucSSID);

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
		help: 'Configure IPv4 settings',
		select_node: 'ucIPv4',
		select: function(ctx, argv) {
			return ctx.set(null, {
				edit : uconfig.lookup([ 'interfaces', ctx.data.name, 'ipv4' ]),
				object_edit: uconfig.lookup([ 'interfaces', ctx.data.name, 'ipv4' ]),
			});
		}
	},

	ipv6: {
		help: 'Configure IPv6 settings',
		select_node: 'ucIPv6',
		select: function(ctx, argv) {
			return ctx.set(null, {
				edit: uconfig.lookup([ 'interfaces', ctx.data.name, 'ipv6' ]),
			});
		}
	},

	'broad-band': {
		help: 'Configure broadband access credentials',
		select_node: 'ucBroadBand',
		select: function(ctx, argv) {
			return ctx.set(null, {
				edit: uconfig.lookup([ 'interfaces', ctx.data.name, 'broad-band' ]),
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
