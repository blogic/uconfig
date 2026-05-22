'use strict';

import * as iwinfo from 'iwinfo';
import * as ubus from 'ubus';

let bandwidths = {
	'2g': {
		'40': [ '1', '9' ],
	},
	'5g': {
		'40': [ '36', '44', '52', '60', '100', '108',
			'116', '124', '132', '140', '149', '157', '165', '173',
			'184', '192' ],
		'80': [ '36', '52', '100', '116', '132', '149' ],
		'160': [ '36', '100' ],
	},
	'6g': {
		'40': [ '1', '5', '9', '13', '17', '21', '25', '29', '33', '37', '41', '45', '49',
			'53', '57', '61', '65', '69', '73', '77', '81', '85', '89', '93', '97',
			'101', '105', '109', '113', '117', '121', '125', '129', '133', '137',
			'141', '145', '149', '153', '157', '161', '165', '169', '173', '177',
			'181', '185', '189', '193', '197', '201', '205', '209', '213', '217',
			'221', '225', '229', '233' ],
		'80': [ '1', '5', '9', '13', '17', '21', '25', '29', '33', '37', '41', '45', '49',
			'53', '57', '61', '65', '69', '73', '77', '81', '85', '89', '93', '97',
			'101', '105', '109', '113', '117', '121', '125', '129', '133', '137',
			'141', '145', '149', '153', '157', '161', '165', '169', '173', '177',
			'181', '185', '189', '193', '197', '201', '205', '209', '213', '217',
			'221', '225', '229' ],
		'160': [ '1', '5', '9', '13', '17', '21', '25', '29', '33', '37', '41', '45', '49',
			'53', '57', '61', '65', '69', '73', '77', '81', '85', '89', '93', '97',
			'101', '105', '109', '113', '117', '121', '125', '129', '133', '137',
			'141', '145', '149', '153', '157', '161', '165', '169', '173', '177',
			'181', '185', '189', '193', '197', '201', '205', '209', '213' ],
		'320': [ '1', '5', '9', '13', '17', '21', '25', '29', '33', '37', '41', '45', '49',
			'53', '57', '61', '65', '69', '73', '77', '81', '85', '89', '93', '97',
			'101', '105', '109', '113', '117', '121', '125', '129', '133', '137',
			'141', '145', '149', '153', '157', '161', '165', '169', '173', '177',
			'181', '185', '189', '193', '197' ],
	}
};

function radios_info() {
	iwinfo.update();

	let wireless_status = ubus.call('network.wireless', 'status');
	if (!wireless_status)
		return {};

	let radios = {};

	for (let radio_name, radio_data in wireless_status) {
		if (!radio_data.interfaces || !length(radio_data.interfaces))
			continue;

		let first_iface = radio_data.interfaces[0];
		if (!first_iface.ifname || !iwinfo.ifaces[first_iface.ifname])
			continue;

		let iface = iwinfo.ifaces[first_iface.ifname];
		let band = radio_data.config?.band;
		if (!band)
			continue;

		let band_key = uc(band);
		if (!radios[band_key])
			radios[band_key] = {};

		let freqlist = iwinfo.freqlist(first_iface.ifname);
		let htmodes = iwinfo.htmodelist(first_iface.ifname);

		let all_channels = [];
		for (let freq in freqlist)
			push(all_channels, '' + freq.channel);

		let channels = { '20': all_channels };

		for (let htmode in htmodes) {
			let bw = replace(htmode, /[A-Z]+/, '');
			if (!bandwidths[band]?.[bw])
				continue;
			channels[bw] = [];
			for (let chan in bandwidths[band][bw])
				if (chan in all_channels)
					push(channels[bw], chan);
		}

		radios[band_key] = { channels };
	}

	return radios;
};

export let methods = {
	radios: {
		call: function(req) {
			return radios_info();
		},
		args: {}
	}
};
