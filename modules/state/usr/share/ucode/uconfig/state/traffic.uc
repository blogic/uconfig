'use strict';

import * as ubus from 'ubus';

let wan_traffic = {
	upload: [],
	download: [],
	last_tx_bytes: [],
	last_rx_bytes: [],
	last_interval: [],
};

const TRAFFIC_RESOLUTIONS = [
	{ count: 12, key: null },
	{ count: 60, key: 'min' },
	{ count: 24, key: 'hour' },
	{ count: 7, key: 'wday' },
];

export function init() {
	for (let i = 0; i < length(TRAFFIC_RESOLUTIONS); i++) {
		wan_traffic.upload[i] = [];
		wan_traffic.download[i] = [];
		wan_traffic.last_tx_bytes[i] = null;
		wan_traffic.last_rx_bytes[i] = null;
		wan_traffic.last_interval[i] = null;

		for (let j = 0; j < TRAFFIC_RESOLUTIONS[i].count; j++) {
			push(wan_traffic.upload[i], 0);
			push(wan_traffic.download[i], 0);
		}
	}
};

function traffic_record_delta(resolution_index, tx_bytes, rx_bytes) {
	let upload_delta = 0;
	let download_delta = 0;

	if (wan_traffic.last_tx_bytes[resolution_index] != null) {
		upload_delta = tx_bytes - wan_traffic.last_tx_bytes[resolution_index];
		download_delta = rx_bytes - wan_traffic.last_rx_bytes[resolution_index];
	}

	wan_traffic.last_tx_bytes[resolution_index] = tx_bytes;
	wan_traffic.last_rx_bytes[resolution_index] = rx_bytes;

	if (upload_delta > 0 || download_delta > 0) {
		push(wan_traffic.upload[resolution_index], upload_delta);
		push(wan_traffic.download[resolution_index], download_delta);
		shift(wan_traffic.upload[resolution_index]);
		shift(wan_traffic.download[resolution_index]);
	}
}

export function update() {
	let device_status = ubus.call('network.device', 'status');
	let wan_stats = device_status?.['br-wan']?.statistics;

	if (!wan_stats)
		return;

	let tx_bytes = wan_stats.tx_bytes;
	let rx_bytes = wan_stats.rx_bytes;

	traffic_record_delta(0, tx_bytes, rx_bytes);

	let current_time = gmtime();
	for (let i = 1; i < length(TRAFFIC_RESOLUTIONS); i++) {
		let interval_key = TRAFFIC_RESOLUTIONS[i].key;
		let current_interval = current_time[interval_key];

		if (wan_traffic.last_interval[i] != current_interval) {
			traffic_record_delta(i, tx_bytes, rx_bytes);
			wan_traffic.last_interval[i] = current_interval;
		}
	}
};

export let methods = {
	traffic: {
		call: function(req) {
			return {
				upload: wan_traffic.upload,
				download: wan_traffic.download,
			};
		},
		args: {}
	}
};
