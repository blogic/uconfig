'use strict';

import * as uci from 'uci';
import * as iwinfo from 'iwinfo';
import { board } from 'uconfig.board_json';

let cursor = uci ? uci.cursor() : null;

export let phys = [];

function freq_to_channel(freq) {
	if (freq == 2484)
		return 14;
	if (freq < 2484)
		return (freq - 2407) / 5;
	if (freq >= 4910 && freq <= 4980)
		return (freq - 4000) / 5;
	if (freq < 5950)
		return (freq - 5000) / 5;
	if (freq <= 45000)
		return (freq - 5950) / 5;
	return 0;
}

function freq_to_band(freq) {
	if (freq < 2500)
		return '2g';
	if (freq < 5950)
		return '5g';
	if (freq <= 7125)
		return '6g';
	return null;
}

function derive_modes(band_data) {
	let modes = [];
	let widths = [20];

	if (band_data.ht_capa) {
		push(modes, 'HT20');
		let has_ht40 = false;
		for (let freq in band_data.freqs)
			if (!freq.no_ht40_minus || !freq.no_ht40_plus)
				has_ht40 = true;
		if (has_ht40) {
			push(modes, 'HT40');
			push(widths, 40);
		}
	}

	if (band_data.vht_capa) {
		push(modes, 'VHT20', 'VHT40');
		let has_80 = false, has_160 = false;
		for (let freq in band_data.freqs) {
			if (!freq.no_80mhz)
				has_80 = true;
			if (!freq.no_160mhz)
				has_160 = true;
		}
		if (has_80) {
			push(modes, 'VHT80');
			push(widths, 80);
		}
		if (has_160) {
			push(modes, 'VHT160');
			push(widths, 160);
		}
	}

	if (band_data.iftype_data) {
		let has_he = false, has_eht = false;
		for (let ifd in band_data.iftype_data) {
			if (ifd.he_cap_phy)
				has_he = true;
			if (ifd.eht_cap_phy)
				has_eht = true;
		}
		if (has_he) {
			push(modes, 'HE20');
			if (40 in widths)
				push(modes, 'HE40');
			if (80 in widths)
				push(modes, 'HE80');
			if (160 in widths)
				push(modes, 'HE160');
		}
		if (has_eht) {
			push(modes, 'EHT20');
			if (40 in widths)
				push(modes, 'EHT40');
			if (80 in widths)
				push(modes, 'EHT80');
			if (160 in widths)
				push(modes, 'EHT160');
			let has_320 = false;
			for (let freq in band_data.freqs)
				if (!freq.no_320mhz)
					has_320 = true;
			if (has_320) {
				push(modes, 'EHT320');
				push(widths, 320);
			}
		}
	}

	return { modes: uniq(modes), widths: uniq(widths) };
}

function build_phy_info(phy) {
	let info = {
		phy: phy.wiphy_name,
		wiphy: phy.wiphy,
		path: board?.wlan?.[phy.wiphy_name]?.path,
		bands: {},
	};

	for (let band_data in phy.wiphy_bands) {
		if (!band_data || !band_data.freqs || !length(band_data.freqs))
			continue;

		let band_name = freq_to_band(band_data.freqs[0].freq);
		if (!band_name)
			continue;

		let channels = [];
		for (let freq in band_data.freqs) {
			if (freq.disabled)
				continue;
			push(channels, {
				channel: freq_to_channel(freq.freq),
				freq: freq.freq,
				max_power: freq.max_tx_power / 100,
				dfs: !!freq.radar,
				no_ir: !!freq.no_ir,
				no_ht40_minus: !!freq.no_ht40_minus,
				no_ht40_plus: !!freq.no_ht40_plus,
				no_80mhz: !!freq.no_80mhz,
				no_160mhz: !!freq.no_160mhz,
				no_320mhz: !!freq.no_320mhz,
			});
		}

		let mode_info = derive_modes(band_data);

		info.bands[uc(band_name)] = {
			channels,
			modes: mode_info.modes,
			widths: mode_info.widths,
			ht_capa: band_data.ht_capa,
			vht_capa: band_data.vht_capa,
			default_channel: channels[0]?.channel,
		};
	}

	return info;
}

function lookup_phys() {
	iwinfo.update();

	for (let phy in iwinfo.phys) {
		let info = build_phy_info(phy);
		if (length(info.bands))
			push(phys, info);
	}
}

/**
 * Convert a wireless channel to a wireless frequency
 *
 * @param {string} wireless band
 * @param {number} channel
 *
 * @returns {?number}
 * Returns the coverted wireless frequency for this specific
 * channel.
 */
export function channel_to_freq(band, channel) {
	if (band == '2G' && channel >= 1 && channel <= 13)
		return 2407 + channel * 5;
	else if (band == '2G' && channel == 14)
		return 2484;
	else if (band == '5G' && channel >= 7 && channel <= 177)
		return 5000 + channel * 5;
	else if (band == '5G' && channel >= 183 && channel <= 196)
		return 4000 + channel * 5;
	else if (band == '6G' && channel >= 1 && channel <= 233)
		return 5950 + channel * 5;
	else if (band == '60G' && channel >= 1 && channel <= 6)
		return 56160 + channel * 2160;

	return null;
};

/**
 * Convert the unique sysfs path describing a wireless PHY to
 * the corresponding UCI section name
 *
 * @param {string} path
 *
 * @returns {string|false}
 * Returns the UCI section name of a specific PHY
 */
export function phy_to_section(path) {
	let sid = null;

	cursor.load("wireless");
	cursor.foreach("wireless", "wifi-device", (s) => {
		if (s.path == path && s.scanning != 1) {
			sid = s['.name'];

			return false;
		}
	});

	return sid;
};

/**
 * Get a list of all wireless PHYs for a specific name/band
 *
 * @param {string} name
 *
 * @returns {object[]}
 * Returns an array of wireless PHYs
 */
export function lookup(name) {
	let ret = [];

	for (let idx, phy in phys)
		if (phy.phy == name || phy.bands[name]) {
			let sid = phy_to_section(phy.path);
			if (sid)
				push(ret, { ...phy, section: sid });
		}

	return ret;
};

lookup_phys();
