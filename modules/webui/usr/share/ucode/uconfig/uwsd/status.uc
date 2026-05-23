'use strict';

import * as ubus from 'ubus';
import * as fs from 'fs';
import * as iwinfo from 'iwinfo';
import { board } from 'uconfig.board_json';

function connectivity_status() {
	let iface_dump = ubus.call('network.interface', 'dump');
	if (!iface_dump?.interface)
		return null;

	let result = {};
	for (let iface in iface_dump.interface) {
		if (!iface.l3_device || !iface.route)
			continue;

		for (let route in iface.route) {
			if (route.target == '0.0.0.0' && route.mask == 0) {
				result.gateway = route.nexthop;
				result.online_since = time() - (iface.uptime || 0);
				if (iface['ipv4-address']?.[0])
					result.ipv4 = iface['ipv4-address'][0].address;
				break;
			}
		}

		if (result.gateway)
			break;
	}

	return result;
}

function ethernet_ports_status() {
	if (!board?.network)
		return {};

	let ports = {};
	for (let name, config in board.network) {
		let port_list = [];

		if (config.device) {
			let carrier_path = sprintf('/sys/class/net/%s/carrier', config.device);
			let speed_path = sprintf('/sys/class/net/%s/speed', config.device);

			let carrier = fs.readfile(carrier_path);
			let speed = fs.readfile(speed_path);

			push(port_list, {
				label: uc(name),
				device: config.device,
				link: carrier && int(trim(carrier)) == 1,
				speed: speed ? int(trim(speed)) : null
			});
		} else if (config.ports) {
			let port_count = length(config.ports);
			for (let i = 0; i < port_count; i++) {
				let device = config.ports[i];
				let carrier_path = sprintf('/sys/class/net/%s/carrier', device);
				let speed_path = sprintf('/sys/class/net/%s/speed', device);

				let carrier = fs.readfile(carrier_path);
				let speed = fs.readfile(speed_path);

				let label = port_count > 1 ? sprintf('%s%d', uc(name), i + 1) : uc(name);

				push(port_list, {
					label: label,
					device: device,
					link: carrier && int(trim(carrier)) == 1,
					speed: speed ? int(trim(speed)) : null
				});
			}
		}

		if (length(port_list) > 0)
			ports[name] = port_list;
	}

	return ports;
}

function client_counts() {
	let devices = ubus.call('uconfig-ui', 'devices');
	if (!devices)
		return {};

	let counts = {};
	for (let network, clients in devices) {
		let online = 0;
		let total = 0;
		for (let mac, client in clients) {
			total++;
			if (client.online)
				online++;
		}
		counts[network] = { online, total };
	}

	return counts;
}

function wifi_networks_status() {
	let wireless_status = ubus.call('network.wireless', 'status');
	if (!wireless_status)
		return {};

	iwinfo.update();

	let networks = {};
	for (let radio_name, radio_data in wireless_status) {
		if (!radio_data.interfaces)
			continue;

		for (let iface in radio_data.interfaces) {
			if (!iface.config?.network?.[0] || !iface.config?.ssid)
				continue;

			let network = iface.config.network[0];
			let ssid = iface.config.ssid;

			if (!networks[network])
				networks[network] = {};

			if (!networks[network][ssid])
				networks[network][ssid] = { ssid, enabled: true, clients: 0 };

			if (iface.ifname && iwinfo.ifaces[iface.ifname]?.assoclist) {
				networks[network][ssid].clients += length(iwinfo.ifaces[iface.ifname].assoclist);
			}
		}
	}

	let result = {};
	for (let network, ssids in networks) {
		for (let ssid, info in ssids) {
			if (!result[network])
				result[network] = [];
			push(result[network], info);
		}
	}

	return result;
}

export function get() {
	return {
		connectivity: connectivity_status(),
		ports: ethernet_ports_status(),
		clients: client_counts(),
		wifi: wifi_networks_status()
	};
};
