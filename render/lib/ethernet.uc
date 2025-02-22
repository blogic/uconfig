/**
 * @class uconfig.ethernet
 * @classdesc
 *
 * This is the ethernet base class. It is automatically instantiated and
 * accessible using the global 'ethernet' variable.
 */

/** @lends uconfig.ethernet.prototype */

'use strict';

let ports;
let port_roles = {};

function discover_ports() {
	let roles = {};

	/* Derive ethernet port names and roles from default config */
	for (let role, spec in capabilities.network) {
		for (let i, ifname in spec) {
			role = lc(role);
			push(roles[role] = roles[role] || [], {
				netdev: ifname,
				index: i
			});
		}
	}

	/* Sort ports in each role group according to their index, then normalize
	 * names into uppercase role name with 1-based index suffix in case of multiple
	 * ports or just uppercase role name in case of single ports */
	let rv = {};

	for (let role, ports in roles) {
		switch (length(ports)) {
		case 0:
			break;

		case 1:
			rv[role] = ports[0];
			break;

		default:
			map(sort(ports, (a, b) => (a.index - b.index)), (port, i) => {
				rv[role + (i + 1)] = port;
			});
		}
	}

	return rv;
}

/**
 * Get a list of all wireless PHYs for a specific wireless band
 *
 * @param {string} band
 *
 * @returns {object}
 * Returns an array of all wireless PHYs for a specific wireless
 * band.
 */
export function lookup(globs) {
	let matched = {};

	for (let glob, tag_state in globs) {
		for (let name, spec in ports) {
			if (wildcard(name, glob)) {
				if (spec.netdev)
					matched[spec.netdev] = tag_state;
				else
					warn("Not implemented yet: mapping switch port to netdev");
			}
		}
	}

	return matched;
};

export function lookup_by_interface_vlan(interface) {
	return lookup(interface.ports);
};

export function lookup_by_interface_spec(interface) {
	return sort(keys(lookup_by_interface_vlan(interface)));
};

export function lookup_by_select_ports(select_ports) {
	return lookup(select_ports);
};

export function lookup_by_ethernet(ethernets) {
	let result = [];

	for (let ethernet in ethernets)
		result = [ ...result,  ...lookup_by_select_ports(ethernet.select_ports) ];

	return result;
};

export function reserve_port(port) {
	delete ports[port];
};

export function assign_port_role(ports, role) {
	for (let port in keys(ports)) {
		port_roles[port] ??= role;
		if (port_roles[port] != role) {
			warn(`trying to use ${ port } as an ${ role } port, but it is already assigned to ${ port_roles[port] }\n`);
			die(`trying to use ${ port } as an ${ role } port, but it is already assigned to ${ port_roles[port] }\n`);
		}
	}
};

export function is_single_config(interface) {
	let ipv4_mode = interface.ipv4 ? interface.ipv4.addressing : 'none';
	let ipv6_mode = interface.ipv6 ? interface.ipv6.addressing : 'none';

	return (
		(ipv4_mode == 'none') || (ipv6_mode == 'none') ||
		(ipv4_mode == 'static' && ipv6_mode == 'static')
	);
};

export function calculate_name(interface) {
	let vid = interface.vlan.id;

	return (interface.role == 'upstream' ? 'br-wan' : 'br-lan') + interface.index + 'v' + vid;
};

export function calculate_names(interface) {
	let name = interface.name;

	return is_single_config(interface) ? [ name ] : [ name + '_4', name + '_6' ];
};

export function calculate_ipv4_name(interface) {
	let name = interface.name;

	return is_single_config(interface) ? name : name + '_4';
};

export function calculate_ipv6_name(interface) {
	let name = interface.name;

	return is_single_config(interface) ? name : name + '_6';
};

export function has_vlan(interface) {
	return interface.vlan && interface.vlan.id;
};

export function port_vlan(interface, port) {
	if (port == "tagged" && has_vlan(interface))
		return ':t';

	if (port == "un-tagged")
		return '';

	return has_vlan(interface) ? ':t' : '';
};

export function find_interface(role, vid) {
	for (let name, interface in state.interfaces) {
		if (interface.role != role)
			continue;
		if (interface.vlan?.id == vid)
			return interface.name;
		if (vid in interface.vlan?.trunks)
			return interface.name;
	}
	return '';
};

export function get_interface(role, vid) {
	for (let name, interface in state.interfaces)
		if (interface.role == role &&
		    interface.vlan.id == vid)
			return interface;
	return null;
};

export function get_speed(dev) {
	let fp = fs.open(sprintf("/sys/class/net/%s/speed", dev));
	if (!fp)
		return 1000;
	let speed = fp.read("all");
	fp.close();
	return +speed;
};

export function init() {
	ports = discover_ports();
	port_roles = {};
};
