'use strict';

import * as libubus from 'ubus';
import * as libuci from 'uci';
import * as nl80211 from 'nl80211';
import * as rtnl from 'rtnl';
import * as fs from 'fs';

let ubus = libubus.connect();
let uci = libuci.cursor();

function board_info(state) {
	let system = ubus.call("system", "info");
	state.board = ubus.call('system', 'board');
	state.unit = { memory: {}};
	state.unit.localtime = system.localtime;
	state.unit.uptime = system.uptime;
	state.unit.load = system.load;
	state.unit.memory.total = system.memory.total;
	state.unit.memory.free = system.memory.free;
	state.storage = system.root;

	for (let l = 0; l < 3; l++)
		state.unit.load[l] /= 65535.0;
}

function ipv4_leases(state) {
	try {
		let fd = fs.open("/tmp/dhcp.leases");
		if (fd) {
			let line;
			while (line = fd.read("line")) {
				let tokens = split(line, " ");
	
				if (length(tokens) < 4)
					continue;
				state.clients[tokens[1]] ??= {};
				state.clients[tokens[1]].dhcp = { 
					assigned: tokens[0],
					address: tokens[2],
					hostname: tokens[3]
				};
			}
			fd.close();
		}
	}
	catch(e) {
		printf("Failed to parse dhcp leases cache: %s\n%s\n", e, e.stacktrace[0].context);
	}
}

function ipv6_leases(state) {
	let ipv6leases = ubus.call("dhcp", "ipv6leases");
	if (!length(ipv6leases))
		return;
/*
	for (let l in ipv6leases.device[status.device].leases) {
		let lease = {};

		lease.hostname = l.hostname;
		lease.addresses = [];
		for (let addr in l["ipv6-addr"])
			push(lease.addresses, addr.address);
		push(leases, lease);
	}
*/
}

function ssids(state) {
	let wifistatus = ubus.call("network.wireless", "status");
	if (!length(wifistatus))
		return;

	state.ssids = {};
	for (let radio, data in wifistatus) {
		for (let k, vap in data.interfaces) {
			let status = ubus.call(`hostapd.${vap.ifname}`, 'get_status');
			if (!status)
				continue;
			let ssid = {
				phy: data.config.path,
				band: uc(data.config.band)
			};
			ssid.ssid = status.ssid;
			ssid.mode = 'ap';
			ssid.bssid = status.bssid;
			ssid.frequency = status.freq;
			ssid.channel = status.channel;
			ssid.network = vap.config.network[0];

			let clients = ubus.call(`hostapd.${vap.ifname}`, 'get_clients');
			ssid.associations = [];
			for (let k, v in clients.clients) {
				push(ssid.associations, k);
				state.clients[k] ??= {};
				state.clients[k].wifi = {};
				for (let a in [ 'bytes', 'packets', 'rate', 'signal', 'ht', 'vht', 'he', 'mfp' ])
					state.clients[k].wifi[a] = v[a];
			}
			state.ssids[vap.ifname] = ssid;
		}
	}
}

function interfaces(state) {
	let devices = ubus.call("network.device", "status");
	uci.load("network");
	uci.foreach("network", "interface", function(d) {
		let name = split(d[".name"], '_')[0];
		if (name == "loopback")
			return;
		if (d.proto == 'none')
			return;
		if (index(name, "_") >= 0)
			return;
		if (!d.uconfig_path)
			return;
	
		let role = split(name, /[[:digit:]]/)[0];
		let vlan = split(name, 'v')[1];
		let iface_port;

		state.interfaces[name] ??= { location: d.uconfig_path, ipv4:{}, ipv6:{} };
		let iface = state.interfaces[name];

		let status = ubus.call(sprintf("network.interface.%s", d[".name"]) , "status");
		if (!length(status))
			return;

		if (devices && devices[role] && length(devices[role]["bridge-members"]))
			iface_ports = devices[role]["bridge-members"];
		iface.uptime = status.uptime || 0;

		if (length(status["ipv4-address"])) {
			let ipv4 = [];

			for (let a in status["ipv4-address"])
				push(ipv4, sprintf("%s/%d", a.address, a.mask));

			iface.ipv4.addresses = ipv4;
		}

		if (length(status["ipv6-address"])) {
			iface.ipv6.addresses = status["ipv6-address"];
			for (let key, addr in iface.ipv6.addresses) {
				if (!addr.mask)
					continue;
				addr.address = sprintf("%s/%s", addr.address, addr.mask);
				delete addr.mask;
			}
		}

		if (length(status["dns-server"]))
			iface.dns_servers = status["dns-server"];

		if (length(status.data) && status.data.ntpserver)
			iface.ntp_server = status.data.ntpserver;

		if (length(status.data) && status.data.leasetime && status.proto == "dhcp") {
			iface.ipv4.leasetime = status.data.leasetime;
			iface.ipv4.dhcp_server = status.data.dhcpserver;
		}
	});
}

export function get() {

	let state = {};

	state.interfaces = {};
	state.clients = {};

	board_info(state);
	ipv4_leases(state);
	ipv6_leases(state);
	ssids(state);
	interfaces(state);

	return state;
};
