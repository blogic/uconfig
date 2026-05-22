'use strict';

import * as rtnl from 'rtnl';
import * as iwinfo from 'iwinfo';
import { readfile, writefile, glob, popen, unlink, stat, mkdir } from 'fs';
import * as ubus from 'ubus';

let l3_devices = {};
let devices_db = {};
let fingerprints = {};
let cached_devices = {};

function check_mac(mac) {
	mac = lc(mac);
	return (match(mac, /33:33:.*/) || match(mac, /01:00:5e.*/) || match(mac, /ff:ff:ff.*/));
}

function add_device(devices, mac) {
	devices[mac] ??= {
		mac,
	};
}

function network_interfaces() {
	let ifaces = ubus.call('network.interface', 'dump');
	if (!ifaces?.interface)
		return;

	l3_devices = {};

	for (let iface in ifaces.interface) {
		if (iface.interface in ['main', 'guest'])
			l3_devices[iface.l3_device] = iface.interface;
	}
}

function arp_discover(devices) {
	let neighs = rtnl.request(rtnl.const.RTM_GETNEIGH, rtnl.const.NLM_F_DUMP, {});

	for (let neigh in neighs) {
		if (!neigh.lladdr)
			continue;

		let mac = lc(neigh.lladdr);
		if (check_mac(mac))
			continue;

		add_device(devices, mac);

		if (l3_devices[neigh.dev])
			devices[mac].network = l3_devices[neigh.dev];

		switch(neigh.family) {
		case rtnl.const.AF_INET:
			devices[mac].ipv4 = neigh.dst;
			break;
		case rtnl.const.AF_INET6:
			devices[mac].ipv6 ??= [];
			push(devices[mac].ipv6, neigh.dst);
			break;
		}

		if (neigh.state == rtnl.const.REACHABLE)
			devices[mac].online = true;
		else if (neigh.cacheinfo?.confirmed < 60 * 1000)
			devices[mac].online = true;
	}
}

function wifi_clients(devices) {
	iwinfo.update();

	let wireless_status = ubus.call('network.wireless', 'status');
	if (!wireless_status)
		return;

	let ifname_to_network = {};
	for (let radio, data in wireless_status) {
		for (let iface in data.interfaces) {
			if (iface.ifname && iface.config?.network?.[0])
				ifname_to_network[iface.ifname] = iface.config.network[0];
		}
	}

	for (let ifname, iface in iwinfo.ifaces) {
		let network = ifname_to_network[ifname];
		if (!network || !iface.assoclist)
			continue;

		for (let station in iface.assoclist) {
			let mac = lc(station.mac);
			add_device(devices, mac);
			devices[mac].network = network;
			devices[mac].wifi = {
				signal: station.sta_info.signal_avg,
				rssi: station.sta_info.signal_avg,
				ifname: ifname,
				ssid: iface.ssid
			};
		}
	}
}

function dhcp_leases(devices) {
	let leases = readfile('/tmp/dhcp.leases');
	if (!leases)
		return;

	let lines = split(leases, '\n');

	for (let line in lines) {
		let values = split(line, ' ');
		if (length(values) != 5)
			continue;

		let mac = lc(values[1]);
		add_device(devices, mac);

		devices[mac].ipv4 = values[2];
		devices[mac].dhcp = 'dynamic';
		if (values[3] != '*')
			devices[mac].hostname ??= values[3];
	}
}

function fingerprint_data(devices) {
	for (let mac, fingerprint in fingerprints) {
		mac = lc(mac);
		if (!devices[mac])
			continue;

		devices[mac].fingerprint = fingerprint;
		if (fingerprint.device_name || fingerprint.device)
			devices[mac].hostname = fingerprint.device_name || fingerprint.device;
	}
}

function nlbwmon(devices) {
	let pipe = popen('nlbw -c show -c json');
	let data = json(pipe.read('all') || '{}');
	pipe.close();
	if (!data?.data)
		return;
	data = data.data;
	for (let traffic in data) {
		let mac = lc(traffic[3]);
		if (!devices[mac])
			continue;
		let type = traffic[10] || 'unknown';
		devices[mac].bytes ??= 0;
		devices[mac].traffic ??= {};
		devices[mac].traffic[type] ??= { bytes: 0 };
		devices[mac].traffic[type].bytes += traffic[6] + traffic[8];
		devices[mac].bytes += traffic[6] + traffic[8];
	}
}

function load_devices() {
	if (!stat('/etc/uconfig/devices'))
		mkdir('/etc/uconfig/devices', 0755);

	let files = glob('/etc/uconfig/devices/*');
	for (let name in files) {
		let data = readfile(name);
		if (data)
			data = json(data);
		if (data)
			devices_db[lc(data.mac)] = data;
	}

	fingerprints = ubus.call('fingerprint', 'fingerprint');
}

function save_device(mac, device) {
	writefile('/etc/uconfig/devices/' + lc(mac), device);
}

function fingerprint_differs(stored_fp, new_fp) {
	if (!stored_fp || !length(stored_fp))
		return !!new_fp && !!length(new_fp);

	if (!new_fp)
		return false;

	for (let key in ['vendor', 'device', 'class', 'device_name']) {
		if (stored_fp[key] != new_fp[key])
			return true;
	}

	return false;
}

function merge_with_db(devices) {
	for (let mac, device in devices) {
		if (!device?.network)
			continue;

		mac = lc(mac);
		let stored = devices_db[mac];

		if (!stored) {
			devices_db[mac] = {
				created: time(),
				mac: device.mac,
			};
			stored = devices_db[mac];
			save_device(mac, stored);
		}

		if (fingerprint_differs(stored.fingerprint, device.fingerprint) ||
		    (!stored.hostname && device.hostname)) {
			if (length(device.fingerprint))
				stored.fingerprint = device.fingerprint;
			if (device.hostname)
				stored.hostname = device.hostname;
			save_device(mac, stored);
		} else if (device.hostname && stored.hostname != device.hostname) {
			stored.hostname = device.hostname;
			save_device(mac, stored);
		}

		device.created = stored.created;
		device.ignore = !!stored.ignore;
		if (stored.name)
			device.name = stored.name;
	}

	for (let mac, stored in devices_db) {
		if (devices[mac])
			continue;

		devices[mac] = {
			mac: stored.mac,
			created: stored.created,
			ignore: !!stored.ignore,
		};

		if (stored.name)
			devices[mac].name = stored.name;
		if (stored.fingerprint)
			devices[mac].fingerprint = stored.fingerprint;
		if (stored.hostname)
			devices[mac].hostname = stored.hostname;
	}
}

function device_key(device) {
	for (let key in [ 'name', 'hostname', 'mac' ])
		if (device[key])
			return lc(device[key]);
}

function correlate_devices() {
	let stations = {};

	network_interfaces();
	arp_discover(stations);
	wifi_clients(stations);
	fingerprint_data(stations);
	dhcp_leases(stations);
	nlbwmon(stations);
	merge_with_db(stations);

	let devices = {};

	for (let mac, station in stations) {
		if (!station?.network)
			continue;
		devices[station.network] ??= {};
		devices[station.network][lc(mac)] = station;
		station.mac = mac;
		delete station.network;
	}

	if (devices.main)
		devices.main = sort(devices.main, (k1, k2, v1, v2) => {
			return device_key(v1) < device_key(v2) ? -1 : 1;
		});

	if (devices.guest)
		devices.guest = sort(devices.guest, (k1, k2, v1, v2) => {
			return device_key(v1) < device_key(v2) ? -1 : 1;
		});

	return devices;
}

export function update() {
	fingerprints = ubus.call('fingerprint', 'fingerprint');
	cached_devices = correlate_devices();
};

export function init() {
	load_devices();
	update();
};

export let methods = {
	devices: {
		call: function(req) {
			return cached_devices;
		},
		args: {}
	},
	device_set_name: {
		call: function(req) {
			let mac = lc(req.args.mac);
			let name = req.args.name;

			if (!mac)
				return { error: 'Missing MAC address' };

			if (!devices_db[mac])
				return { error: 'Device not found' };

			if (name && length(name) > 0) {
				devices_db[mac].name = name;
			} else {
				delete devices_db[mac].name;
			}

			save_device(mac, devices_db[mac]);
			return { success: true };
		},
		args: {
			mac: '00:00:00:00:00:00',
			name: ''
		}
	},
	device_set_ignore: {
		call: function(req) {
			let mac = lc(req.args.mac);
			let ignore = req.args.ignore;

			if (!mac)
				return { error: 'Missing MAC address' };

			if (!devices_db[mac])
				return { error: 'Device not found' };

			if (ignore) {
				devices_db[mac].ignore = true;
			} else {
				delete devices_db[mac].ignore;
			}

			save_device(mac, devices_db[mac]);
			return { success: true };
		},
		args: {
			mac: '00:00:00:00:00:00',
			ignore: false
		}
	},
	device_delete: {
		call: function(req) {
			let mac = lc(req.args.mac);

			if (!mac)
				return { error: 'Missing MAC address' };

			if (!devices_db[mac])
				return { error: 'Device not found' };

			delete devices_db[mac];

			unlink('/etc/uconfig/devices/' + mac);

			return { success: true };
		},
		args: {
			mac: '00:00:00:00:00:00'
		}
	},
	trigger_discovery: {
		call: function(req) {
			update_devices();
			return { success: true };
		},
		args: {}
	}
};
