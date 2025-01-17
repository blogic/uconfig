// Automatically ureader from ./schema-generated/schema.json - do not edit!
"use strict";

function matchUcCidr4(value) {
	let m = match(value, /^(auto|[0-9.]+)\/([0-9]+)$/);
	return m ? ((m[1] == "auto" || length(iptoarr(m[1])) == 4) && +m[2] <= 32) : false;
}

function matchUcCidr6(value) {
	let m = match(value, /^(auto|[0-9a-fA-F:.]+)\/([0-9]+)$/);
	return m ? ((m[1] == "auto" || length(iptoarr(m[1])) == 16) && +m[2] <= 128) : false;
}

function matchUcCidr(value) {
	let m = match(value, /^(auto|[0-9a-fA-F:.]+)\/([0-9]+)$/);
	if (!m) return false;
	let l = (m[1] == "auto") ? 16 : length(iptoarr(m[1]));
	return (l > 0 && +m[2] <= (l * 8));
}

function matchUcMac(value) {
	return match(value, /^[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]$/i);
}

function matchUcHost(value) {
	if (length(iptoarr(value)) != 0) return true;
	if (length(value) > 255) return false;
	let labels = split(value, ".");
	return (length(filter(labels, label => !match(label, /^([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9])$/))) == 0 && length(labels) > 0);
}

function matchUcTimeout(value) {
	return match(value, /^[0-9]+[smhdw]$/);
}

function matchUcBase64(value) {
	return b64dec(value) != null;
}

function matchUcPortrange(value) {
	let ports = match(value, /^([0-9]|[1-9][0-9]*)(-([0-9]|[1-9][0-9]*))?$/);
	if (!ports) return false;
	let min = +ports[1], max = ports[2] ? +ports[3] : min;
	return (min <= 65535 && max <= 65535 && max >= min);
}

function matchHostname(value) {
	if (length(value) > 255) return false;
	let labels = split(value, ".");
	return (length(filter(labels, label => !match(label, /^([a-zA-Z0-9]{1,2}|[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9])$/))) == 0 && length(labels) > 0);
}

function matchUcFqdn(value) {
	if (length(value) > 255) return false;
	let labels = split(value, ".");
	return (length(filter(labels, label => !match(label, /^([a-zA-Z0-9]{1,2}|[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9])$/))) == 0 && length(labels) > 1);
}

function matchUcIp(value) {
	return (length(iptoarr(value)) == 4 || length(iptoarr(value)) == 16);
}

function matchIpv4(value) {
	return (length(iptoarr(value)) == 4);
}

function matchIpv6(value) {
	return (length(iptoarr(value)) == 16);
}

function matchUri(value) {
	if (index(value, "data:") == 0) return true;
	let m = match(value, /^[a-z+-]+:\/\/([^\/]+).*$/);
	if (!m) return false;
	if (length(iptoarr(m[1])) != 0) return true;
	if (length(m[1]) > 255) return false;
	let labels = split(m[1], ".");
	return (length(filter(labels, label => !match(label, /^([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9])$/))) == 0 && length(labels) > 0);
}

function instantiateUnit(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		function parseName(location, value, errors) {
			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			return value;
		}

		if (exists(value, "name")) {
			obj.name = parseName(location + "/name", value["name"], errors);
		}

		function parseHostname(location, value, errors) {
			if (type(value) == "string") {
				if (!matchHostname(value))
					push(errors, [ location, "must be a valid hostname" ]);

			}

			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			return value;
		}

		if (exists(value, "hostname")) {
			obj.hostname = parseHostname(location + "/hostname", value["hostname"], errors);
		}

		function parseLocation(location, value, errors) {
			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			return value;
		}

		if (exists(value, "location")) {
			obj.location = parseLocation(location + "/location", value["location"], errors);
		}

		function parseTimezone(location, value, errors) {
			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			return value;
		}

		if (exists(value, "timezone")) {
			obj.timezone = parseTimezone(location + "/timezone", value["timezone"], errors);
		}

		function parseLedsActive(location, value, errors) {
			if (type(value) != "bool")
				push(errors, [ location, "must be of type boolean" ]);

			return value;
		}

		if (exists(value, "leds-active")) {
			obj.leds_active = parseLedsActive(location + "/leds-active", value["leds-active"], errors);
		}
		else {
			obj.leds_active = true;
		}

		function parsePassword(location, value, errors) {
			function parseVariant0(location, value, errors) {
				if (type(value) != "bool")
					push(errors, [ location, "must be of type boolean" ]);

				return value;
			}

			function parseVariant1(location, value, errors) {
				if (type(value) != "string")
					push(errors, [ location, "must be of type string" ]);

				return value;
			}

			let success = 0, tryval, tryerr, vvalue = null, verrors = [];

			tryerr = [];
			tryval = parseVariant0(location, value, tryerr);
			if (!length(tryerr)) {
				if (type(vvalue) == "object" && type(tryval) == "object")
					vvalue = { ...vvalue, ...tryval };
				else
					vvalue = tryval;

				success++;
			}
			else {
				push(verrors, join(" and\n", map(tryerr, err => "\t - " + err[1])));
			}

			tryerr = [];
			tryval = parseVariant1(location, value, tryerr);
			if (!length(tryerr)) {
				if (type(vvalue) == "object" && type(tryval) == "object")
					vvalue = { ...vvalue, ...tryval };
				else
					vvalue = tryval;

				success++;
			}
			else {
				push(verrors, join(" and\n", map(tryerr, err => "\t - " + err[1])));
			}

			if (success != 1) {
				if (length(verrors))
					push(errors, [ location, "must match exactly one of the following constraints:\n" + join("\n- or -\n", verrors) ]);
				else
					push(errors, [ location, "must match only one variant" ]);
				return null;
			}

			value = vvalue;

			return value;
		}

		if (exists(value, "password")) {
			obj.password = parsePassword(location + "/password", value["password"], errors);
		}

		function parseTtyLogin(location, value, errors) {
			if (type(value) != "bool")
				push(errors, [ location, "must be of type boolean" ]);

			return value;
		}

		if (exists(value, "tty-login")) {
			obj.tty_login = parseTtyLogin(location + "/tty-login", value["tty-login"], errors);
		}
		else {
			obj.tty_login = true;
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

function instantiateGlobalsWirelessMultimediaClassSelector(location, value, errors) {
	if (type(value) == "array") {
		function parseItem(location, value, errors) {
			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			if (!(value in [ "CS0", "CS1", "CS2", "CS3", "CS4", "CS5", "CS6", "CS7", "AF11", "AF12", "AF13", "AF21", "AF22", "AF23", "AF31", "AF32", "AF33", "AF41", "AF42", "AF43", "DF", "EF", "VA", "LE" ]))
				push(errors, [ location, "must be one of \"CS0\", \"CS1\", \"CS2\", \"CS3\", \"CS4\", \"CS5\", \"CS6\", \"CS7\", \"AF11\", \"AF12\", \"AF13\", \"AF21\", \"AF22\", \"AF23\", \"AF31\", \"AF32\", \"AF33\", \"AF41\", \"AF42\", \"AF43\", \"DF\", \"EF\", \"VA\" or \"LE\"" ]);

			return value;
		}

		return map(value, (item, i) => parseItem(location + "/" + i, item, errors));
	}

	if (type(value) != "array")
		push(errors, [ location, "must be of type array" ]);

	return value;
}

function instantiateGlobalsWirelessMultimediaTable(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		if (exists(value, "UP0")) {
			obj.UP0 = instantiateGlobalsWirelessMultimediaClassSelector(location + "/UP0", value["UP0"], errors);
		}

		if (exists(value, "UP1")) {
			obj.UP1 = instantiateGlobalsWirelessMultimediaClassSelector(location + "/UP1", value["UP1"], errors);
		}

		if (exists(value, "UP2")) {
			obj.UP2 = instantiateGlobalsWirelessMultimediaClassSelector(location + "/UP2", value["UP2"], errors);
		}

		if (exists(value, "UP3")) {
			obj.UP3 = instantiateGlobalsWirelessMultimediaClassSelector(location + "/UP3", value["UP3"], errors);
		}

		if (exists(value, "UP4")) {
			obj.UP4 = instantiateGlobalsWirelessMultimediaClassSelector(location + "/UP4", value["UP4"], errors);
		}

		if (exists(value, "UP5")) {
			obj.UP5 = instantiateGlobalsWirelessMultimediaClassSelector(location + "/UP5", value["UP5"], errors);
		}

		if (exists(value, "UP6")) {
			obj.UP6 = instantiateGlobalsWirelessMultimediaClassSelector(location + "/UP6", value["UP6"], errors);
		}

		if (exists(value, "UP7")) {
			obj.UP7 = instantiateGlobalsWirelessMultimediaClassSelector(location + "/UP7", value["UP7"], errors);
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

function instantiateGlobalsWirelessMultimediaProfile(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		function parseProfile(location, value, errors) {
			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			if (!(value in [ "enterprise", "rfc8325", "3gpp" ]))
				push(errors, [ location, "must be one of \"enterprise\", \"rfc8325\" or \"3gpp\"" ]);

			return value;
		}

		if (exists(value, "profile")) {
			obj.profile = parseProfile(location + "/profile", value["profile"], errors);
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

function instantiateGlobals(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		function parseIpv4Network(location, value, errors) {
			if (type(value) == "string") {
				if (!matchUcCidr4(value))
					push(errors, [ location, "must be a valid IPv4 CIDR" ]);

			}

			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			return value;
		}

		if (exists(value, "ipv4-network")) {
			obj.ipv4_network = parseIpv4Network(location + "/ipv4-network", value["ipv4-network"], errors);
		}

		function parseIpv6Network(location, value, errors) {
			if (type(value) == "string") {
				if (!matchUcCidr6(value))
					push(errors, [ location, "must be a valid IPv6 CIDR" ]);

			}

			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			return value;
		}

		if (exists(value, "ipv6-network")) {
			obj.ipv6_network = parseIpv6Network(location + "/ipv6-network", value["ipv6-network"], errors);
		}

		function parseWirelessMultimedia(location, value, errors) {
			function parseVariant0(location, value, errors) {
				value = instantiateGlobalsWirelessMultimediaTable(location, value, errors);

				return value;
			}

			function parseVariant1(location, value, errors) {
				value = instantiateGlobalsWirelessMultimediaProfile(location, value, errors);

				return value;
			}

			let success = 0, tryval, tryerr, vvalue = null, verrors = [];

			tryerr = [];
			tryval = parseVariant0(location, value, tryerr);
			if (!length(tryerr)) {
				if (type(vvalue) == "object" && type(tryval) == "object")
					vvalue = { ...vvalue, ...tryval };
				else
					vvalue = tryval;

				success++;
			}
			else {
				push(verrors, join(" and\n", map(tryerr, err => "\t - " + err[1])));
			}

			tryerr = [];
			tryval = parseVariant1(location, value, tryerr);
			if (!length(tryerr)) {
				if (type(vvalue) == "object" && type(tryval) == "object")
					vvalue = { ...vvalue, ...tryval };
				else
					vvalue = tryval;

				success++;
			}
			else {
				push(verrors, join(" and\n", map(tryerr, err => "\t - " + err[1])));
			}

			if (success == 0) {
				if (length(verrors))
					push(errors, [ location, "must match at least one of the following constraints:\n" + join("\n- or -\n", verrors) ]);
				else
					push(errors, [ location, "must match only one variant" ]);
				return null;
			}

			value = vvalue;

			return value;
		}

		if (exists(value, "wireless-multimedia")) {
			obj.wireless_multimedia = parseWirelessMultimedia(location + "/wireless-multimedia", value["wireless-multimedia"], errors);
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

function instantiateEthernet(location, value, errors) {
	if (type(value) == "array") {
		function parseItem(location, value, errors) {
			if (type(value) == "object") {
				let obj = {};

				function parseSelectPorts(location, value, errors) {
					if (type(value) == "array") {
						function parseItem(location, value, errors) {
							if (type(value) != "string")
								push(errors, [ location, "must be of type string" ]);

							return value;
						}

						return map(value, (item, i) => parseItem(location + "/" + i, item, errors));
					}

					if (type(value) != "array")
						push(errors, [ location, "must be of type array" ]);

					return value;
				}

				if (exists(value, "select-ports")) {
					obj.select_ports = parseSelectPorts(location + "/select-ports", value["select-ports"], errors);
				}

				function parseSpeed(location, value, errors) {
					if (type(value) != "int")
						push(errors, [ location, "must be of type integer" ]);

					if (!(value in [ 10, 100, 1000, 2500, 5000, 10000 ]))
						push(errors, [ location, "must be one of 10, 100, 1000, 2500, 5000 or 10000" ]);

					return value;
				}

				if (exists(value, "speed")) {
					obj.speed = parseSpeed(location + "/speed", value["speed"], errors);
				}

				function parseDuplex(location, value, errors) {
					if (type(value) != "string")
						push(errors, [ location, "must be of type string" ]);

					if (!(value in [ "half", "full" ]))
						push(errors, [ location, "must be one of \"half\" or \"full\"" ]);

					return value;
				}

				if (exists(value, "duplex")) {
					obj.duplex = parseDuplex(location + "/duplex", value["duplex"], errors);
				}

				return obj;
			}

			if (type(value) != "object")
				push(errors, [ location, "must be of type object" ]);

			return value;
		}

		return map(value, (item, i) => parseItem(location + "/" + i, item, errors));
	}

	if (type(value) != "array")
		push(errors, [ location, "must be of type array" ]);

	return value;
}

function instantiateRadioRates(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		function parseBeacon(location, value, errors) {
			if (type(value) != "int")
				push(errors, [ location, "must be of type integer" ]);

			if (!(value in [ 0, 1000, 2000, 5500, 6000, 9000, 11000, 12000, 18000, 24000, 36000, 48000, 54000 ]))
				push(errors, [ location, "must be one of 0, 1000, 2000, 5500, 6000, 9000, 11000, 12000, 18000, 24000, 36000, 48000 or 54000" ]);

			return value;
		}

		if (exists(value, "beacon")) {
			obj.beacon = parseBeacon(location + "/beacon", value["beacon"], errors);
		}
		else {
			obj.beacon = 6000;
		}

		function parseMulticast(location, value, errors) {
			if (type(value) != "int")
				push(errors, [ location, "must be of type integer" ]);

			if (!(value in [ 0, 1000, 2000, 5500, 6000, 9000, 11000, 12000, 18000, 24000, 36000, 48000, 54000 ]))
				push(errors, [ location, "must be one of 0, 1000, 2000, 5500, 6000, 9000, 11000, 12000, 18000, 24000, 36000, 48000 or 54000" ]);

			return value;
		}

		if (exists(value, "multicast")) {
			obj.multicast = parseMulticast(location + "/multicast", value["multicast"], errors);
		}
		else {
			obj.multicast = 24000;
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

function instantiateRadioHe(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		function parseMultipleBssid(location, value, errors) {
			if (type(value) != "bool")
				push(errors, [ location, "must be of type boolean" ]);

			return value;
		}

		if (exists(value, "multiple-bssid")) {
			obj.multiple_bssid = parseMultipleBssid(location + "/multiple-bssid", value["multiple-bssid"], errors);
		}
		else {
			obj.multiple_bssid = false;
		}

		function parseBssColor(location, value, errors) {
			if (type(value) != "int")
				push(errors, [ location, "must be of type integer" ]);

			return value;
		}

		if (exists(value, "bss-color")) {
			obj.bss_color = parseBssColor(location + "/bss-color", value["bss-color"], errors);
		}
		else {
			obj.bss_color = 64;
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

function instantiateRadio(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		function parseDisable(location, value, errors) {
			if (type(value) != "bool")
				push(errors, [ location, "must be of type boolean" ]);

			return value;
		}

		if (exists(value, "disable")) {
			obj.disable = parseDisable(location + "/disable", value["disable"], errors);
		}

		function parseBand(location, value, errors) {
			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			if (!(value in [ "2G", "5G", "6G" ]))
				push(errors, [ location, "must be one of \"2G\", \"5G\" or \"6G\"" ]);

			return value;
		}

		if (exists(value, "band")) {
			obj.band = parseBand(location + "/band", value["band"], errors);
		}

		function parseChannel(location, value, errors) {
			function parseVariant0(location, value, errors) {
				if (type(value) in [ "int", "double" ]) {
					if (value > 196)
						push(errors, [ location, "must be lower than or equal to 196" ]);

					if (value < 1)
						push(errors, [ location, "must be bigger than or equal to 1" ]);

				}

				if (type(value) != "int")
					push(errors, [ location, "must be of type integer" ]);

				return value;
			}

			function parseVariant1(location, value, errors) {
				if (type(value) != "string")
					push(errors, [ location, "must be of type string" ]);

				if (value != "auto")
					push(errors, [ location, "must have value \"auto\"" ]);

				return value;
			}

			let success = 0, tryval, tryerr, vvalue = null, verrors = [];

			tryerr = [];
			tryval = parseVariant0(location, value, tryerr);
			if (!length(tryerr)) {
				if (type(vvalue) == "object" && type(tryval) == "object")
					vvalue = { ...vvalue, ...tryval };
				else
					vvalue = tryval;

				success++;
			}
			else {
				push(verrors, join(" and\n", map(tryerr, err => "\t - " + err[1])));
			}

			tryerr = [];
			tryval = parseVariant1(location, value, tryerr);
			if (!length(tryerr)) {
				if (type(vvalue) == "object" && type(tryval) == "object")
					vvalue = { ...vvalue, ...tryval };
				else
					vvalue = tryval;

				success++;
			}
			else {
				push(verrors, join(" and\n", map(tryerr, err => "\t - " + err[1])));
			}

			if (success != 1) {
				if (length(verrors))
					push(errors, [ location, "must match exactly one of the following constraints:\n" + join("\n- or -\n", verrors) ]);
				else
					push(errors, [ location, "must match only one variant" ]);
				return null;
			}

			value = vvalue;

			return value;
		}

		if (exists(value, "channel")) {
			obj.channel = parseChannel(location + "/channel", value["channel"], errors);
		}

		function parseValidChannels(location, value, errors) {
			if (type(value) == "array") {
				function parseItem(location, value, errors) {
					if (type(value) in [ "int", "double" ]) {
						if (value > 196)
							push(errors, [ location, "must be lower than or equal to 196" ]);

						if (value < 1)
							push(errors, [ location, "must be bigger than or equal to 1" ]);

					}

					if (type(value) != "int")
						push(errors, [ location, "must be of type integer" ]);

					return value;
				}

				return map(value, (item, i) => parseItem(location + "/" + i, item, errors));
			}

			if (type(value) != "array")
				push(errors, [ location, "must be of type array" ]);

			return value;
		}

		if (exists(value, "valid-channels")) {
			obj.valid_channels = parseValidChannels(location + "/valid-channels", value["valid-channels"], errors);
		}

		function parseAllowDfs(location, value, errors) {
			if (type(value) != "bool")
				push(errors, [ location, "must be of type boolean" ]);

			return value;
		}

		if (exists(value, "allow-dfs")) {
			obj.allow_dfs = parseAllowDfs(location + "/allow-dfs", value["allow-dfs"], errors);
		}
		else {
			obj.allow_dfs = true;
		}

		function parseChannelMode(location, value, errors) {
			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			if (!(value in [ "HT", "VHT", "HE", "EHT" ]))
				push(errors, [ location, "must be one of \"HT\", \"VHT\", \"HE\" or \"EHT\"" ]);

			return value;
		}

		if (exists(value, "channel-mode")) {
			obj.channel_mode = parseChannelMode(location + "/channel-mode", value["channel-mode"], errors);
		}
		else {
			obj.channel_mode = "HE";
		}

		function parseChannelWidth(location, value, errors) {
			if (type(value) != "int")
				push(errors, [ location, "must be of type integer" ]);

			if (!(value in [ 20, 40, 80, 160, 8080 ]))
				push(errors, [ location, "must be one of 20, 40, 80, 160 or 8080" ]);

			return value;
		}

		if (exists(value, "channel-width")) {
			obj.channel_width = parseChannelWidth(location + "/channel-width", value["channel-width"], errors);
		}
		else {
			obj.channel_width = 80;
		}

		function parseRequireMode(location, value, errors) {
			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			if (!(value in [ "HT", "VHT", "HE" ]))
				push(errors, [ location, "must be one of \"HT\", \"VHT\" or \"HE\"" ]);

			return value;
		}

		if (exists(value, "require-mode")) {
			obj.require_mode = parseRequireMode(location + "/require-mode", value["require-mode"], errors);
		}

		function parseMimo(location, value, errors) {
			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			if (!(value in [ "1x1", "2x2", "3x3", "4x4", "5x5", "6x6", "7x7", "8x8" ]))
				push(errors, [ location, "must be one of \"1x1\", \"2x2\", \"3x3\", \"4x4\", \"5x5\", \"6x6\", \"7x7\" or \"8x8\"" ]);

			return value;
		}

		if (exists(value, "mimo")) {
			obj.mimo = parseMimo(location + "/mimo", value["mimo"], errors);
		}

		function parseTxPower(location, value, errors) {
			if (type(value) in [ "int", "double" ]) {
				if (value > 30)
					push(errors, [ location, "must be lower than or equal to 30" ]);

				if (value < 0)
					push(errors, [ location, "must be bigger than or equal to 0" ]);

			}

			if (type(value) != "int")
				push(errors, [ location, "must be of type integer" ]);

			return value;
		}

		if (exists(value, "tx-power")) {
			obj.tx_power = parseTxPower(location + "/tx-power", value["tx-power"], errors);
		}

		function parseLegacyRates(location, value, errors) {
			if (type(value) != "bool")
				push(errors, [ location, "must be of type boolean" ]);

			return value;
		}

		if (exists(value, "legacy-rates")) {
			obj.legacy_rates = parseLegacyRates(location + "/legacy-rates", value["legacy-rates"], errors);
		}
		else {
			obj.legacy_rates = false;
		}

		function parseBeaconInterval(location, value, errors) {
			if (type(value) in [ "int", "double" ]) {
				if (value > 65535)
					push(errors, [ location, "must be lower than or equal to 65535" ]);

				if (value < 15)
					push(errors, [ location, "must be bigger than or equal to 15" ]);

			}

			if (type(value) != "int")
				push(errors, [ location, "must be of type integer" ]);

			return value;
		}

		if (exists(value, "beacon-interval")) {
			obj.beacon_interval = parseBeaconInterval(location + "/beacon-interval", value["beacon-interval"], errors);
		}
		else {
			obj.beacon_interval = 100;
		}

		function parseDtimPeriod(location, value, errors) {
			if (type(value) in [ "int", "double" ]) {
				if (value > 255)
					push(errors, [ location, "must be lower than or equal to 255" ]);

				if (value < 1)
					push(errors, [ location, "must be bigger than or equal to 1" ]);

			}

			if (type(value) != "int")
				push(errors, [ location, "must be of type integer" ]);

			return value;
		}

		if (exists(value, "dtim-period")) {
			obj.dtim_period = parseDtimPeriod(location + "/dtim-period", value["dtim-period"], errors);
		}
		else {
			obj.dtim_period = 2;
		}

		function parseMaximumClients(location, value, errors) {
			if (type(value) != "int")
				push(errors, [ location, "must be of type integer" ]);

			return value;
		}

		if (exists(value, "maximum-clients")) {
			obj.maximum_clients = parseMaximumClients(location + "/maximum-clients", value["maximum-clients"], errors);
		}

		if (exists(value, "rates")) {
			obj.rates = instantiateRadioRates(location + "/rates", value["rates"], errors);
		}

		if (exists(value, "he-settings")) {
			obj.he_settings = instantiateRadioHe(location + "/he-settings", value["he-settings"], errors);
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

function instantiateInterfaceVlan(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		function parseId(location, value, errors) {
			if (type(value) in [ "int", "double" ]) {
				if (value > 4050)
					push(errors, [ location, "must be lower than or equal to 4050" ]);

			}

			if (type(value) != "int")
				push(errors, [ location, "must be of type integer" ]);

			return value;
		}

		if (exists(value, "id")) {
			obj.id = parseId(location + "/id", value["id"], errors);
		}

		function parseProto(location, value, errors) {
			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			if (!(value in [ "802.1ad", "802.1q" ]))
				push(errors, [ location, "must be one of \"802.1ad\" or \"802.1q\"" ]);

			return value;
		}

		if (exists(value, "proto")) {
			obj.proto = parseProto(location + "/proto", value["proto"], errors);
		}
		else {
			obj.proto = "802.1q";
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

function instantiateInterfaceBridge(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		function parseName(location, value, errors) {
			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			return value;
		}

		if (exists(value, "name")) {
			obj.name = parseName(location + "/name", value["name"], errors);
		}
		else {
			obj.name = "sw";
		}

		function parseMtu(location, value, errors) {
			if (type(value) in [ "int", "double" ]) {
				if (value > 65535)
					push(errors, [ location, "must be lower than or equal to 65535" ]);

				if (value < 256)
					push(errors, [ location, "must be bigger than or equal to 256" ]);

			}

			if (type(value) != "int")
				push(errors, [ location, "must be of type integer" ]);

			return value;
		}

		if (exists(value, "mtu")) {
			obj.mtu = parseMtu(location + "/mtu", value["mtu"], errors);
		}

		function parseTxQueueLen(location, value, errors) {
			if (type(value) != "int")
				push(errors, [ location, "must be of type integer" ]);

			return value;
		}

		if (exists(value, "tx-queue-len")) {
			obj.tx_queue_len = parseTxQueueLen(location + "/tx-queue-len", value["tx-queue-len"], errors);
		}

		function parseIsolatePorts(location, value, errors) {
			if (type(value) != "bool")
				push(errors, [ location, "must be of type boolean" ]);

			return value;
		}

		if (exists(value, "isolate-ports")) {
			obj.isolate_ports = parseIsolatePorts(location + "/isolate-ports", value["isolate-ports"], errors);
		}
		else {
			obj.isolate_ports = false;
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

function instantiateInterfacePorts(location, value, errors) {
	if (type(value) != "string")
		push(errors, [ location, "must be of type string" ]);

	if (!(value in [ "auto", "tagged", "un-tagged" ]))
		push(errors, [ location, "must be one of \"auto\", \"tagged\" or \"un-tagged\"" ]);

	return value;
}

function instantiateInterfaceIpv4Dhcp(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		function parseLeaseFirst(location, value, errors) {
			if (type(value) != "int")
				push(errors, [ location, "must be of type integer" ]);

			return value;
		}

		if (exists(value, "lease-first")) {
			obj.lease_first = parseLeaseFirst(location + "/lease-first", value["lease-first"], errors);
		}

		function parseLeaseCount(location, value, errors) {
			if (type(value) != "int")
				push(errors, [ location, "must be of type integer" ]);

			return value;
		}

		if (exists(value, "lease-count")) {
			obj.lease_count = parseLeaseCount(location + "/lease-count", value["lease-count"], errors);
		}

		function parseLeaseTime(location, value, errors) {
			if (type(value) == "string") {
				if (!matchUcTimeout(value))
					push(errors, [ location, "must be a valid timeout value" ]);

			}

			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			return value;
		}

		if (exists(value, "lease-time")) {
			obj.lease_time = parseLeaseTime(location + "/lease-time", value["lease-time"], errors);
		}
		else {
			obj.lease_time = "6h";
		}

		function parseUseDns(location, value, errors) {
			if (type(value) == "array") {
				function parseItem(location, value, errors) {
					if (type(value) == "string") {
						if (!matchIpv4(value))
							push(errors, [ location, "must be a valid IPv4 address" ]);

					}

					if (type(value) != "string")
						push(errors, [ location, "must be of type string" ]);

					return value;
				}

				return map(value, (item, i) => parseItem(location + "/" + i, item, errors));
			}

			if (type(value) != "array")
				push(errors, [ location, "must be of type array" ]);

			return value;
		}

		if (exists(value, "use-dns")) {
			obj.use_dns = parseUseDns(location + "/use-dns", value["use-dns"], errors);
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

function instantiateInterfaceIpv4DhcpLease(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		function parseMacaddr(location, value, errors) {
			if (type(value) == "string") {
				if (!matchUcMac(value))
					push(errors, [ location, "must be a valid MAC address" ]);

			}

			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			return value;
		}

		if (exists(value, "macaddr")) {
			obj.macaddr = parseMacaddr(location + "/macaddr", value["macaddr"], errors);
		}

		function parseStaticLeaseOffset(location, value, errors) {
			if (type(value) != "int")
				push(errors, [ location, "must be of type integer" ]);

			return value;
		}

		if (exists(value, "static-lease-offset")) {
			obj.static_lease_offset = parseStaticLeaseOffset(location + "/static-lease-offset", value["static-lease-offset"], errors);
		}

		function parseLeaseTime(location, value, errors) {
			if (type(value) == "string") {
				if (!matchUcTimeout(value))
					push(errors, [ location, "must be a valid timeout value" ]);

			}

			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			return value;
		}

		if (exists(value, "lease-time")) {
			obj.lease_time = parseLeaseTime(location + "/lease-time", value["lease-time"], errors);
		}
		else {
			obj.lease_time = "6h";
		}

		function parsePublishHostname(location, value, errors) {
			if (type(value) != "bool")
				push(errors, [ location, "must be of type boolean" ]);

			return value;
		}

		if (exists(value, "publish-hostname")) {
			obj.publish_hostname = parsePublishHostname(location + "/publish-hostname", value["publish-hostname"], errors);
		}
		else {
			obj.publish_hostname = true;
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

function instantiateInterfaceIpv4(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		function parseAddressing(location, value, errors) {
			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			if (!(value in [ "dynamic", "static", "none" ]))
				push(errors, [ location, "must be one of \"dynamic\", \"static\" or \"none\"" ]);

			return value;
		}

		if (exists(value, "addressing")) {
			obj.addressing = parseAddressing(location + "/addressing", value["addressing"], errors);
		}

		function parseSubnet(location, value, errors) {
			if (type(value) == "string") {
				if (!matchUcCidr4(value))
					push(errors, [ location, "must be a valid IPv4 CIDR" ]);

			}

			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			return value;
		}

		if (exists(value, "subnet")) {
			obj.subnet = parseSubnet(location + "/subnet", value["subnet"], errors);
		}

		function parseGateway(location, value, errors) {
			if (type(value) == "string") {
				if (!matchIpv4(value))
					push(errors, [ location, "must be a valid IPv4 address" ]);

			}

			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			return value;
		}

		if (exists(value, "gateway")) {
			obj.gateway = parseGateway(location + "/gateway", value["gateway"], errors);
		}

		function parseSendHostname(location, value, errors) {
			if (type(value) != "bool")
				push(errors, [ location, "must be of type boolean" ]);

			return value;
		}

		if (exists(value, "send-hostname")) {
			obj.send_hostname = parseSendHostname(location + "/send-hostname", value["send-hostname"], errors);
		}
		else {
			obj.send_hostname = true;
		}

		function parseUseDns(location, value, errors) {
			if (type(value) == "array") {
				function parseItem(location, value, errors) {
					if (type(value) == "string") {
						if (!matchIpv4(value))
							push(errors, [ location, "must be a valid IPv4 address" ]);

					}

					if (type(value) != "string")
						push(errors, [ location, "must be of type string" ]);

					return value;
				}

				return map(value, (item, i) => parseItem(location + "/" + i, item, errors));
			}

			if (type(value) != "array")
				push(errors, [ location, "must be of type array" ]);

			return value;
		}

		if (exists(value, "use-dns")) {
			obj.use_dns = parseUseDns(location + "/use-dns", value["use-dns"], errors);
		}

		function parseDisallowUpstreamSubnet(location, value, errors) {
			function parseVariant0(location, value, errors) {
				if (type(value) != "bool")
					push(errors, [ location, "must be of type boolean" ]);

				return value;
			}

			function parseVariant1(location, value, errors) {
				if (type(value) == "array") {
					function parseItem(location, value, errors) {
						if (type(value) == "string") {
							if (!matchUcCidr4(value))
								push(errors, [ location, "must be a valid IPv4 CIDR" ]);

						}

						if (type(value) != "string")
							push(errors, [ location, "must be of type string" ]);

						return value;
					}

					return map(value, (item, i) => parseItem(location + "/" + i, item, errors));
				}

				if (type(value) != "array")
					push(errors, [ location, "must be of type array" ]);

				return value;
			}

			let success = 0, tryval, tryerr, vvalue = null, verrors = [];

			tryerr = [];
			tryval = parseVariant0(location, value, tryerr);
			if (!length(tryerr)) {
				if (type(vvalue) == "object" && type(tryval) == "object")
					vvalue = { ...vvalue, ...tryval };
				else
					vvalue = tryval;

				success++;
			}
			else {
				push(verrors, join(" and\n", map(tryerr, err => "\t - " + err[1])));
			}

			tryerr = [];
			tryval = parseVariant1(location, value, tryerr);
			if (!length(tryerr)) {
				if (type(vvalue) == "object" && type(tryval) == "object")
					vvalue = { ...vvalue, ...tryval };
				else
					vvalue = tryval;

				success++;
			}
			else {
				push(verrors, join(" and\n", map(tryerr, err => "\t - " + err[1])));
			}

			if (success == 0) {
				if (length(verrors))
					push(errors, [ location, "must match at least one of the following constraints:\n" + join("\n- or -\n", verrors) ]);
				else
					push(errors, [ location, "must match only one variant" ]);
				return null;
			}

			value = vvalue;

			return value;
		}

		if (exists(value, "disallow-upstream-subnet")) {
			obj.disallow_upstream_subnet = parseDisallowUpstreamSubnet(location + "/disallow-upstream-subnet", value["disallow-upstream-subnet"], errors);
		}

		if (exists(value, "dhcp")) {
			obj.dhcp = instantiateInterfaceIpv4Dhcp(location + "/dhcp", value["dhcp"], errors);
		}

		function parseDhcpLeases(location, value, errors) {
			if (type(value) == "array") {
				return map(value, (item, i) => instantiateInterfaceIpv4DhcpLease(location + "/" + i, item, errors));
			}

			if (type(value) != "array")
				push(errors, [ location, "must be of type array" ]);

			return value;
		}

		if (exists(value, "dhcp-leases")) {
			obj.dhcp_leases = parseDhcpLeases(location + "/dhcp-leases", value["dhcp-leases"], errors);
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

function instantiateInterfaceIpv6Dhcpv6(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		function parseMode(location, value, errors) {
			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			if (!(value in [ "hybrid", "stateless", "stateful", "relay" ]))
				push(errors, [ location, "must be one of \"hybrid\", \"stateless\", \"stateful\" or \"relay\"" ]);

			return value;
		}

		if (exists(value, "mode")) {
			obj.mode = parseMode(location + "/mode", value["mode"], errors);
		}

		function parseAnnounceDns(location, value, errors) {
			if (type(value) == "array") {
				function parseItem(location, value, errors) {
					if (type(value) == "string") {
						if (!matchIpv6(value))
							push(errors, [ location, "must be a valid IPv6 address" ]);

					}

					if (type(value) != "string")
						push(errors, [ location, "must be of type string" ]);

					return value;
				}

				return map(value, (item, i) => parseItem(location + "/" + i, item, errors));
			}

			if (type(value) != "array")
				push(errors, [ location, "must be of type array" ]);

			return value;
		}

		if (exists(value, "announce-dns")) {
			obj.announce_dns = parseAnnounceDns(location + "/announce-dns", value["announce-dns"], errors);
		}

		function parseFilterPrefix(location, value, errors) {
			if (type(value) == "string") {
				if (!matchUcCidr6(value))
					push(errors, [ location, "must be a valid IPv6 CIDR" ]);

			}

			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			return value;
		}

		if (exists(value, "filter-prefix")) {
			obj.filter_prefix = parseFilterPrefix(location + "/filter-prefix", value["filter-prefix"], errors);
		}
		else {
			obj.filter_prefix = "::/0";
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

function instantiateInterfaceIpv6(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		function parseAddressing(location, value, errors) {
			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			if (!(value in [ "dynamic", "static" ]))
				push(errors, [ location, "must be one of \"dynamic\" or \"static\"" ]);

			return value;
		}

		if (exists(value, "addressing")) {
			obj.addressing = parseAddressing(location + "/addressing", value["addressing"], errors);
		}

		function parseSubnet(location, value, errors) {
			if (type(value) == "string") {
				if (!matchUcCidr6(value))
					push(errors, [ location, "must be a valid IPv6 CIDR" ]);

			}

			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			return value;
		}

		if (exists(value, "subnet")) {
			obj.subnet = parseSubnet(location + "/subnet", value["subnet"], errors);
		}

		function parseGateway(location, value, errors) {
			if (type(value) == "string") {
				if (!matchIpv6(value))
					push(errors, [ location, "must be a valid IPv6 address" ]);

			}

			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			return value;
		}

		if (exists(value, "gateway")) {
			obj.gateway = parseGateway(location + "/gateway", value["gateway"], errors);
		}

		function parsePrefixSize(location, value, errors) {
			if (type(value) in [ "int", "double" ]) {
				if (value > 64)
					push(errors, [ location, "must be lower than or equal to 64" ]);

				if (value < 0)
					push(errors, [ location, "must be bigger than or equal to 0" ]);

			}

			if (type(value) != "int")
				push(errors, [ location, "must be of type integer" ]);

			return value;
		}

		if (exists(value, "prefix-size")) {
			obj.prefix_size = parsePrefixSize(location + "/prefix-size", value["prefix-size"], errors);
		}

		if (exists(value, "dhcpv6")) {
			obj.dhcpv6 = instantiateInterfaceIpv6Dhcpv6(location + "/dhcpv6", value["dhcpv6"], errors);
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

function instantiateInterfaceSsidEncryption(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		function parseProto(location, value, errors) {
			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			if (!(value in [ "none", "owe", "owe-transition", "psk", "psk2", "psk-mixed", "wpa", "wpa2", "wpa-mixed", "sae", "sae-mixed", "wpa3", "wpa3-192", "wpa3-mixed" ]))
				push(errors, [ location, "must be one of \"none\", \"owe\", \"owe-transition\", \"psk\", \"psk2\", \"psk-mixed\", \"wpa\", \"wpa2\", \"wpa-mixed\", \"sae\", \"sae-mixed\", \"wpa3\", \"wpa3-192\" or \"wpa3-mixed\"" ]);

			return value;
		}

		if (exists(value, "proto")) {
			obj.proto = parseProto(location + "/proto", value["proto"], errors);
		}

		function parseKey(location, value, errors) {
			if (type(value) == "string") {
				if (length(value) > 63)
					push(errors, [ location, "must be at most 63 characters long" ]);

				if (length(value) < 8)
					push(errors, [ location, "must be at least 8 characters long" ]);

			}

			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			return value;
		}

		if (exists(value, "key")) {
			obj.key = parseKey(location + "/key", value["key"], errors);
		}

		function parseIeee80211w(location, value, errors) {
			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			if (!(value in [ "disabled", "optional", "required" ]))
				push(errors, [ location, "must be one of \"disabled\", \"optional\" or \"required\"" ]);

			return value;
		}

		if (exists(value, "ieee80211w")) {
			obj.ieee80211w = parseIeee80211w(location + "/ieee80211w", value["ieee80211w"], errors);
		}
		else {
			obj.ieee80211w = "disabled";
		}

		function parseKeyCaching(location, value, errors) {
			if (type(value) != "bool")
				push(errors, [ location, "must be of type boolean" ]);

			return value;
		}

		if (exists(value, "key-caching")) {
			obj.key_caching = parseKeyCaching(location + "/key-caching", value["key-caching"], errors);
		}
		else {
			obj.key_caching = true;
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

function instantiateInterfaceSsidMultiPsk(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		function parseMac(location, value, errors) {
			if (type(value) == "string") {
				if (!matchUcMac(value))
					push(errors, [ location, "must be a valid MAC address" ]);

			}

			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			return value;
		}

		if (exists(value, "mac")) {
			obj.mac = parseMac(location + "/mac", value["mac"], errors);
		}

		function parseKey(location, value, errors) {
			if (type(value) == "string") {
				if (length(value) > 63)
					push(errors, [ location, "must be at most 63 characters long" ]);

				if (length(value) < 8)
					push(errors, [ location, "must be at least 8 characters long" ]);

			}

			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			return value;
		}

		if (exists(value, "key")) {
			obj.key = parseKey(location + "/key", value["key"], errors);
		}

		function parseVlanId(location, value, errors) {
			if (type(value) in [ "int", "double" ]) {
				if (value > 4096)
					push(errors, [ location, "must be lower than or equal to 4096" ]);

			}

			if (type(value) != "int")
				push(errors, [ location, "must be of type integer" ]);

			return value;
		}

		if (exists(value, "vlan-id")) {
			obj.vlan_id = parseVlanId(location + "/vlan-id", value["vlan-id"], errors);
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

function instantiateInterfaceSsidRrm(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		function parseNeighborReporting(location, value, errors) {
			if (type(value) != "bool")
				push(errors, [ location, "must be of type boolean" ]);

			return value;
		}

		if (exists(value, "neighbor-reporting")) {
			obj.neighbor_reporting = parseNeighborReporting(location + "/neighbor-reporting", value["neighbor-reporting"], errors);
		}
		else {
			obj.neighbor_reporting = false;
		}

		function parseLci(location, value, errors) {
			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			return value;
		}

		if (exists(value, "lci")) {
			obj.lci = parseLci(location + "/lci", value["lci"], errors);
		}

		function parseCivicLocation(location, value, errors) {
			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			return value;
		}

		if (exists(value, "civic-location")) {
			obj.civic_location = parseCivicLocation(location + "/civic-location", value["civic-location"], errors);
		}

		function parseFtmResponder(location, value, errors) {
			if (type(value) != "bool")
				push(errors, [ location, "must be of type boolean" ]);

			return value;
		}

		if (exists(value, "ftm-responder")) {
			obj.ftm_responder = parseFtmResponder(location + "/ftm-responder", value["ftm-responder"], errors);
		}
		else {
			obj.ftm_responder = false;
		}

		function parseStationaryAp(location, value, errors) {
			if (type(value) != "bool")
				push(errors, [ location, "must be of type boolean" ]);

			return value;
		}

		if (exists(value, "stationary-ap")) {
			obj.stationary_ap = parseStationaryAp(location + "/stationary-ap", value["stationary-ap"], errors);
		}
		else {
			obj.stationary_ap = false;
		}

		function parseReducedNeighborReporting(location, value, errors) {
			if (type(value) != "bool")
				push(errors, [ location, "must be of type boolean" ]);

			return value;
		}

		if (exists(value, "reduced-neighbor-reporting")) {
			obj.reduced_neighbor_reporting = parseReducedNeighborReporting(location + "/reduced-neighbor-reporting", value["reduced-neighbor-reporting"], errors);
		}
		else {
			obj.reduced_neighbor_reporting = false;
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

function instantiateInterfaceSsidRateLimit(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		function parseIngressRate(location, value, errors) {
			if (type(value) != "int")
				push(errors, [ location, "must be of type integer" ]);

			return value;
		}

		if (exists(value, "ingress-rate")) {
			obj.ingress_rate = parseIngressRate(location + "/ingress-rate", value["ingress-rate"], errors);
		}
		else {
			obj.ingress_rate = 0;
		}

		function parseEgressRate(location, value, errors) {
			if (type(value) != "int")
				push(errors, [ location, "must be of type integer" ]);

			return value;
		}

		if (exists(value, "egress-rate")) {
			obj.egress_rate = parseEgressRate(location + "/egress-rate", value["egress-rate"], errors);
		}
		else {
			obj.egress_rate = 0;
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

function instantiateInterfaceSsidRoaming(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		function parseMessageExchange(location, value, errors) {
			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			if (!(value in [ "air", "ds" ]))
				push(errors, [ location, "must be one of \"air\" or \"ds\"" ]);

			return value;
		}

		if (exists(value, "message-exchange")) {
			obj.message_exchange = parseMessageExchange(location + "/message-exchange", value["message-exchange"], errors);
		}
		else {
			obj.message_exchange = "air";
		}

		function parseGeneratePsk(location, value, errors) {
			if (type(value) != "bool")
				push(errors, [ location, "must be of type boolean" ]);

			return value;
		}

		if (exists(value, "generate-psk")) {
			obj.generate_psk = parseGeneratePsk(location + "/generate-psk", value["generate-psk"], errors);
		}
		else {
			obj.generate_psk = true;
		}

		function parseDomainIdentifier(location, value, errors) {
			if (type(value) == "string") {
				if (length(value) > 4)
					push(errors, [ location, "must be at most 4 characters long" ]);

				if (length(value) < 4)
					push(errors, [ location, "must be at least 4 characters long" ]);

			}

			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			return value;
		}

		if (exists(value, "domain-identifier")) {
			obj.domain_identifier = parseDomainIdentifier(location + "/domain-identifier", value["domain-identifier"], errors);
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

function instantiateInterfaceSsidRadiusLocalUser(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		function parseMac(location, value, errors) {
			if (type(value) == "string") {
				if (!matchUcMac(value))
					push(errors, [ location, "must be a valid MAC address" ]);

			}

			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			return value;
		}

		if (exists(value, "mac")) {
			obj.mac = parseMac(location + "/mac", value["mac"], errors);
		}

		function parseUserName(location, value, errors) {
			if (type(value) == "string") {
				if (length(value) < 1)
					push(errors, [ location, "must be at least 1 characters long" ]);

			}

			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			return value;
		}

		if (exists(value, "user-name")) {
			obj.user_name = parseUserName(location + "/user-name", value["user-name"], errors);
		}

		function parsePassword(location, value, errors) {
			if (type(value) == "string") {
				if (length(value) > 63)
					push(errors, [ location, "must be at most 63 characters long" ]);

				if (length(value) < 8)
					push(errors, [ location, "must be at least 8 characters long" ]);

			}

			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			return value;
		}

		if (exists(value, "password")) {
			obj.password = parsePassword(location + "/password", value["password"], errors);
		}

		function parseVlanId(location, value, errors) {
			if (type(value) in [ "int", "double" ]) {
				if (value > 4096)
					push(errors, [ location, "must be lower than or equal to 4096" ]);

			}

			if (type(value) != "int")
				push(errors, [ location, "must be of type integer" ]);

			return value;
		}

		if (exists(value, "vlan-id")) {
			obj.vlan_id = parseVlanId(location + "/vlan-id", value["vlan-id"], errors);
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

function instantiateInterfaceSsidRadiusLocal(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		function parseServerIdentity(location, value, errors) {
			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			return value;
		}

		if (exists(value, "server-identity")) {
			obj.server_identity = parseServerIdentity(location + "/server-identity", value["server-identity"], errors);
		}
		else {
			obj.server_identity = "OpenWrt";
		}

		function parseUsers(location, value, errors) {
			if (type(value) == "array") {
				return map(value, (item, i) => instantiateInterfaceSsidRadiusLocalUser(location + "/" + i, item, errors));
			}

			if (type(value) != "array")
				push(errors, [ location, "must be of type array" ]);

			return value;
		}

		if (exists(value, "users")) {
			obj.users = parseUsers(location + "/users", value["users"], errors);
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

function instantiateInterfaceSsidRadiusServer(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		function parseHost(location, value, errors) {
			if (type(value) == "string") {
				if (!matchUcHost(value))
					push(errors, [ location, "must be a valid hostname or IP address" ]);

			}

			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			return value;
		}

		if (exists(value, "host")) {
			obj.host = parseHost(location + "/host", value["host"], errors);
		}

		function parsePort(location, value, errors) {
			if (type(value) in [ "int", "double" ]) {
				if (value > 65535)
					push(errors, [ location, "must be lower than or equal to 65535" ]);

				if (value < 1024)
					push(errors, [ location, "must be bigger than or equal to 1024" ]);

			}

			if (type(value) != "int")
				push(errors, [ location, "must be of type integer" ]);

			return value;
		}

		if (exists(value, "port")) {
			obj.port = parsePort(location + "/port", value["port"], errors);
		}

		function parseSecret(location, value, errors) {
			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			return value;
		}

		if (exists(value, "secret")) {
			obj.secret = parseSecret(location + "/secret", value["secret"], errors);
		}

		function parseRequestAttribute(location, value, errors) {
			if (type(value) == "array") {
				function parseItem(location, value, errors) {
					if (type(value) == "object") {
						let obj = {};

						function parseId(location, value, errors) {
							if (type(value) in [ "int", "double" ]) {
								if (value > 255)
									push(errors, [ location, "must be lower than or equal to 255" ]);

								if (value < 1)
									push(errors, [ location, "must be bigger than or equal to 1" ]);

							}

							if (type(value) != "int")
								push(errors, [ location, "must be of type integer" ]);

							return value;
						}

						if (exists(value, "id")) {
							obj.id = parseId(location + "/id", value["id"], errors);
						}

						function parseValue(location, value, errors) {
							function parseVariant0(location, value, errors) {
								if (type(value) in [ "int", "double" ]) {
									if (value > 4294967295)
										push(errors, [ location, "must be lower than or equal to 4294967295" ]);

									if (value < 0)
										push(errors, [ location, "must be bigger than or equal to 0" ]);

								}

								if (type(value) != "int")
									push(errors, [ location, "must be of type integer" ]);

								return value;
							}

							function parseVariant1(location, value, errors) {
								if (type(value) != "string")
									push(errors, [ location, "must be of type string" ]);

								return value;
							}

							let success = 0, tryval, tryerr, vvalue = null, verrors = [];

							tryerr = [];
							tryval = parseVariant0(location, value, tryerr);
							if (!length(tryerr)) {
								if (type(vvalue) == "object" && type(tryval) == "object")
									vvalue = { ...vvalue, ...tryval };
								else
									vvalue = tryval;

								success++;
							}
							else {
								push(verrors, join(" and\n", map(tryerr, err => "\t - " + err[1])));
							}

							tryerr = [];
							tryval = parseVariant1(location, value, tryerr);
							if (!length(tryerr)) {
								if (type(vvalue) == "object" && type(tryval) == "object")
									vvalue = { ...vvalue, ...tryval };
								else
									vvalue = tryval;

								success++;
							}
							else {
								push(verrors, join(" and\n", map(tryerr, err => "\t - " + err[1])));
							}

							if (success == 0) {
								if (length(verrors))
									push(errors, [ location, "must match at least one of the following constraints:\n" + join("\n- or -\n", verrors) ]);
								else
									push(errors, [ location, "must match only one variant" ]);
								return null;
							}

							value = vvalue;

							return value;
						}

						if (exists(value, "value")) {
							obj.value = parseValue(location + "/value", value["value"], errors);
						}

						return obj;
					}

					if (type(value) != "object")
						push(errors, [ location, "must be of type object" ]);

					return value;
				}

				return map(value, (item, i) => parseItem(location + "/" + i, item, errors));
			}

			if (type(value) != "array")
				push(errors, [ location, "must be of type array" ]);

			return value;
		}

		if (exists(value, "request-attribute")) {
			obj.request_attribute = parseRequestAttribute(location + "/request-attribute", value["request-attribute"], errors);
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

function instantiateInterfaceSsidRadius(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		function parseNasIdentifier(location, value, errors) {
			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			return value;
		}

		if (exists(value, "nas-identifier")) {
			obj.nas_identifier = parseNasIdentifier(location + "/nas-identifier", value["nas-identifier"], errors);
		}

		function parseChargeableUserId(location, value, errors) {
			if (type(value) != "bool")
				push(errors, [ location, "must be of type boolean" ]);

			return value;
		}

		if (exists(value, "chargeable-user-id")) {
			obj.chargeable_user_id = parseChargeableUserId(location + "/chargeable-user-id", value["chargeable-user-id"], errors);
		}
		else {
			obj.chargeable_user_id = false;
		}

		if (exists(value, "local")) {
			obj.local = instantiateInterfaceSsidRadiusLocal(location + "/local", value["local"], errors);
		}

		function parseDynamicAuthorization(location, value, errors) {
			if (type(value) == "object") {
				let obj = {};

				function parseHost(location, value, errors) {
					if (type(value) == "string") {
						if (!matchUcIp(value))
							push(errors, [ location, "must be a valid IPv4 or IPv6 address" ]);

					}

					if (type(value) != "string")
						push(errors, [ location, "must be of type string" ]);

					return value;
				}

				if (exists(value, "host")) {
					obj.host = parseHost(location + "/host", value["host"], errors);
				}

				function parsePort(location, value, errors) {
					if (type(value) in [ "int", "double" ]) {
						if (value > 65535)
							push(errors, [ location, "must be lower than or equal to 65535" ]);

						if (value < 1024)
							push(errors, [ location, "must be bigger than or equal to 1024" ]);

					}

					if (type(value) != "int")
						push(errors, [ location, "must be of type integer" ]);

					return value;
				}

				if (exists(value, "port")) {
					obj.port = parsePort(location + "/port", value["port"], errors);
				}

				function parseSecret(location, value, errors) {
					if (type(value) != "string")
						push(errors, [ location, "must be of type string" ]);

					return value;
				}

				if (exists(value, "secret")) {
					obj.secret = parseSecret(location + "/secret", value["secret"], errors);
				}

				return obj;
			}

			if (type(value) != "object")
				push(errors, [ location, "must be of type object" ]);

			return value;
		}

		if (exists(value, "dynamic-authorization")) {
			obj.dynamic_authorization = parseDynamicAuthorization(location + "/dynamic-authorization", value["dynamic-authorization"], errors);
		}

		function parseAuthentication(location, value, errors) {
			function parseVariant0(location, value, errors) {
				value = instantiateInterfaceSsidRadiusServer(location, value, errors);

				return value;
			}

			function parseVariant1(location, value, errors) {
				if (type(value) == "object") {
					let obj = {};

					function parseMacFilter(location, value, errors) {
						if (type(value) != "bool")
							push(errors, [ location, "must be of type boolean" ]);

						return value;
					}

					if (exists(value, "mac-filter")) {
						obj.mac_filter = parseMacFilter(location + "/mac-filter", value["mac-filter"], errors);
					}
					else {
						obj.mac_filter = false;
					}

					return obj;
				}

				if (type(value) != "object")
					push(errors, [ location, "must be of type object" ]);

				return value;
			}

			let success = 0, tryval, tryerr, vvalue = null, verrors = [];

			tryerr = [];
			tryval = parseVariant0(location, value, tryerr);
			if (!length(tryerr)) {
				if (type(vvalue) == "object" && type(tryval) == "object")
					vvalue = { ...vvalue, ...tryval };
				else
					vvalue = tryval;

				success++;
			}
			else {
				push(verrors, join(" and\n", map(tryerr, err => "\t - " + err[1])));
			}

			tryerr = [];
			tryval = parseVariant1(location, value, tryerr);
			if (!length(tryerr)) {
				if (type(vvalue) == "object" && type(tryval) == "object")
					vvalue = { ...vvalue, ...tryval };
				else
					vvalue = tryval;

				success++;
			}
			else {
				push(verrors, join(" and\n", map(tryerr, err => "\t - " + err[1])));
			}

			if (success != 2) {
				if (length(verrors))
					push(errors, [ location, "must match all of the following constraints:\n" + join("\n- or -\n", verrors) ]);
				else
					push(errors, [ location, "must match only one variant" ]);
				return null;
			}

			value = vvalue;

			return value;
		}

		if (exists(value, "authentication")) {
			obj.authentication = parseAuthentication(location + "/authentication", value["authentication"], errors);
		}

		function parseAccounting(location, value, errors) {
			function parseVariant0(location, value, errors) {
				value = instantiateInterfaceSsidRadiusServer(location, value, errors);

				return value;
			}

			function parseVariant1(location, value, errors) {
				if (type(value) == "object") {
					let obj = {};

					function parseInterval(location, value, errors) {
						if (type(value) in [ "int", "double" ]) {
							if (value > 600)
								push(errors, [ location, "must be lower than or equal to 600" ]);

							if (value < 60)
								push(errors, [ location, "must be bigger than or equal to 60" ]);

						}

						if (type(value) != "int")
							push(errors, [ location, "must be of type integer" ]);

						return value;
					}

					if (exists(value, "interval")) {
						obj.interval = parseInterval(location + "/interval", value["interval"], errors);
					}
					else {
						obj.interval = 60;
					}

					return obj;
				}

				if (type(value) != "object")
					push(errors, [ location, "must be of type object" ]);

				return value;
			}

			let success = 0, tryval, tryerr, vvalue = null, verrors = [];

			tryerr = [];
			tryval = parseVariant0(location, value, tryerr);
			if (!length(tryerr)) {
				if (type(vvalue) == "object" && type(tryval) == "object")
					vvalue = { ...vvalue, ...tryval };
				else
					vvalue = tryval;

				success++;
			}
			else {
				push(verrors, join(" and\n", map(tryerr, err => "\t - " + err[1])));
			}

			tryerr = [];
			tryval = parseVariant1(location, value, tryerr);
			if (!length(tryerr)) {
				if (type(vvalue) == "object" && type(tryval) == "object")
					vvalue = { ...vvalue, ...tryval };
				else
					vvalue = tryval;

				success++;
			}
			else {
				push(verrors, join(" and\n", map(tryerr, err => "\t - " + err[1])));
			}

			if (success != 2) {
				if (length(verrors))
					push(errors, [ location, "must match all of the following constraints:\n" + join("\n- or -\n", verrors) ]);
				else
					push(errors, [ location, "must match only one variant" ]);
				return null;
			}

			value = vvalue;

			return value;
		}

		if (exists(value, "accounting")) {
			obj.accounting = parseAccounting(location + "/accounting", value["accounting"], errors);
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

function instantiateInterfaceSsidAcl(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		function parseMode(location, value, errors) {
			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			if (!(value in [ "allow", "deny" ]))
				push(errors, [ location, "must be one of \"allow\" or \"deny\"" ]);

			return value;
		}

		if (exists(value, "mode")) {
			obj.mode = parseMode(location + "/mode", value["mode"], errors);
		}

		function parseMacAddress(location, value, errors) {
			if (type(value) == "array") {
				function parseItem(location, value, errors) {
					if (type(value) == "string") {
						if (!matchUcMac(value))
							push(errors, [ location, "must be a valid MAC address" ]);

					}

					if (type(value) != "string")
						push(errors, [ location, "must be of type string" ]);

					return value;
				}

				return map(value, (item, i) => parseItem(location + "/" + i, item, errors));
			}

			if (type(value) != "array")
				push(errors, [ location, "must be of type array" ]);

			return value;
		}

		if (exists(value, "mac-address")) {
			obj.mac_address = parseMacAddress(location + "/mac-address", value["mac-address"], errors);
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

function instantiateInterfaceSsid(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		function parsePurpose(location, value, errors) {
			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			if (!(value in [ "user-defined", "system-defaults" ]))
				push(errors, [ location, "must be one of \"user-defined\" or \"system-defaults\"" ]);

			return value;
		}

		if (exists(value, "purpose")) {
			obj.purpose = parsePurpose(location + "/purpose", value["purpose"], errors);
		}
		else {
			obj.purpose = "user-defined";
		}

		function parseSsid(location, value, errors) {
			if (type(value) == "string") {
				if (length(value) > 32)
					push(errors, [ location, "must be at most 32 characters long" ]);

				if (length(value) < 1)
					push(errors, [ location, "must be at least 1 characters long" ]);

			}

			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			return value;
		}

		if (exists(value, "ssid")) {
			obj.ssid = parseSsid(location + "/ssid", value["ssid"], errors);
		}

		function parseWifiRadios(location, value, errors) {
			if (type(value) == "array") {
				function parseItem(location, value, errors) {
					if (type(value) != "string")
						push(errors, [ location, "must be of type string" ]);

					return value;
				}

				return map(value, (item, i) => parseItem(location + "/" + i, item, errors));
			}

			if (type(value) != "array")
				push(errors, [ location, "must be of type array" ]);

			return value;
		}

		if (exists(value, "wifi-radios")) {
			obj.wifi_radios = parseWifiRadios(location + "/wifi-radios", value["wifi-radios"], errors);
		}

		function parseBssMode(location, value, errors) {
			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			if (!(value in [ "ap", "sta", "mesh", "wds-ap", "wds-sta", "wds-repeater" ]))
				push(errors, [ location, "must be one of \"ap\", \"sta\", \"mesh\", \"wds-ap\", \"wds-sta\" or \"wds-repeater\"" ]);

			return value;
		}

		if (exists(value, "bss-mode")) {
			obj.bss_mode = parseBssMode(location + "/bss-mode", value["bss-mode"], errors);
		}
		else {
			obj.bss_mode = "ap";
		}

		function parseBssid(location, value, errors) {
			if (type(value) == "string") {
				if (!matchUcMac(value))
					push(errors, [ location, "must be a valid MAC address" ]);

			}

			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			return value;
		}

		if (exists(value, "bssid")) {
			obj.bssid = parseBssid(location + "/bssid", value["bssid"], errors);
		}

		function parseHiddenSsid(location, value, errors) {
			if (type(value) != "bool")
				push(errors, [ location, "must be of type boolean" ]);

			return value;
		}

		if (exists(value, "hidden-ssid")) {
			obj.hidden_ssid = parseHiddenSsid(location + "/hidden-ssid", value["hidden-ssid"], errors);
		}

		function parseIsolateClients(location, value, errors) {
			if (type(value) != "bool")
				push(errors, [ location, "must be of type boolean" ]);

			return value;
		}

		if (exists(value, "isolate-clients")) {
			obj.isolate_clients = parseIsolateClients(location + "/isolate-clients", value["isolate-clients"], errors);
		}

		function parsePowerSave(location, value, errors) {
			if (type(value) != "bool")
				push(errors, [ location, "must be of type boolean" ]);

			return value;
		}

		if (exists(value, "power-save")) {
			obj.power_save = parsePowerSave(location + "/power-save", value["power-save"], errors);
		}
		else {
			obj.power_save = true;
		}

		function parseRtsThreshold(location, value, errors) {
			if (type(value) in [ "int", "double" ]) {
				if (value > 65535)
					push(errors, [ location, "must be lower than or equal to 65535" ]);

				if (value < 1)
					push(errors, [ location, "must be bigger than or equal to 1" ]);

			}

			if (type(value) != "int")
				push(errors, [ location, "must be of type integer" ]);

			return value;
		}

		if (exists(value, "rts-threshold")) {
			obj.rts_threshold = parseRtsThreshold(location + "/rts-threshold", value["rts-threshold"], errors);
		}

		function parseBroadcastTime(location, value, errors) {
			if (type(value) != "bool")
				push(errors, [ location, "must be of type boolean" ]);

			return value;
		}

		if (exists(value, "broadcast-time")) {
			obj.broadcast_time = parseBroadcastTime(location + "/broadcast-time", value["broadcast-time"], errors);
		}

		function parseUnicastConversion(location, value, errors) {
			if (type(value) != "bool")
				push(errors, [ location, "must be of type boolean" ]);

			return value;
		}

		if (exists(value, "unicast-conversion")) {
			obj.unicast_conversion = parseUnicastConversion(location + "/unicast-conversion", value["unicast-conversion"], errors);
		}

		function parseServices(location, value, errors) {
			if (type(value) == "array") {
				function parseItem(location, value, errors) {
					if (type(value) != "string")
						push(errors, [ location, "must be of type string" ]);

					return value;
				}

				return map(value, (item, i) => parseItem(location + "/" + i, item, errors));
			}

			if (type(value) != "array")
				push(errors, [ location, "must be of type array" ]);

			return value;
		}

		if (exists(value, "services")) {
			obj.services = parseServices(location + "/services", value["services"], errors);
		}

		function parseProxyArp(location, value, errors) {
			if (type(value) != "bool")
				push(errors, [ location, "must be of type boolean" ]);

			return value;
		}

		if (exists(value, "proxy-arp")) {
			obj.proxy_arp = parseProxyArp(location + "/proxy-arp", value["proxy-arp"], errors);
		}
		else {
			obj.proxy_arp = false;
		}

		function parseDisassocLowAck(location, value, errors) {
			if (type(value) != "bool")
				push(errors, [ location, "must be of type boolean" ]);

			return value;
		}

		if (exists(value, "disassoc-low-ack")) {
			obj.disassoc_low_ack = parseDisassocLowAck(location + "/disassoc-low-ack", value["disassoc-low-ack"], errors);
		}
		else {
			obj.disassoc_low_ack = false;
		}

		function parseVendorElements(location, value, errors) {
			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			return value;
		}

		if (exists(value, "vendor-elements")) {
			obj.vendor_elements = parseVendorElements(location + "/vendor-elements", value["vendor-elements"], errors);
		}

		function parseFilsDiscoveryInterval(location, value, errors) {
			if (type(value) in [ "int", "double" ]) {
				if (value > 20)
					push(errors, [ location, "must be lower than or equal to 20" ]);

			}

			if (type(value) != "int")
				push(errors, [ location, "must be of type integer" ]);

			return value;
		}

		if (exists(value, "fils-discovery-interval")) {
			obj.fils_discovery_interval = parseFilsDiscoveryInterval(location + "/fils-discovery-interval", value["fils-discovery-interval"], errors);
		}
		else {
			obj.fils_discovery_interval = 20;
		}

		function parseDtimPeriod(location, value, errors) {
			if (type(value) in [ "int", "double" ]) {
				if (value > 255)
					push(errors, [ location, "must be lower than or equal to 255" ]);

				if (value < 1)
					push(errors, [ location, "must be bigger than or equal to 1" ]);

			}

			if (type(value) != "int")
				push(errors, [ location, "must be of type integer" ]);

			return value;
		}

		if (exists(value, "dtim-period")) {
			obj.dtim_period = parseDtimPeriod(location + "/dtim-period", value["dtim-period"], errors);
		}
		else {
			obj.dtim_period = 2;
		}

		if (exists(value, "encryption")) {
			obj.encryption = instantiateInterfaceSsidEncryption(location + "/encryption", value["encryption"], errors);
		}

		function parseMultiPsk(location, value, errors) {
			if (type(value) == "array") {
				return map(value, (item, i) => instantiateInterfaceSsidMultiPsk(location + "/" + i, item, errors));
			}

			if (type(value) != "array")
				push(errors, [ location, "must be of type array" ]);

			return value;
		}

		if (exists(value, "multi-psk")) {
			obj.multi_psk = parseMultiPsk(location + "/multi-psk", value["multi-psk"], errors);
		}

		if (exists(value, "rrm")) {
			obj.rrm = instantiateInterfaceSsidRrm(location + "/rrm", value["rrm"], errors);
		}

		if (exists(value, "rate-limit")) {
			obj.rate_limit = instantiateInterfaceSsidRateLimit(location + "/rate-limit", value["rate-limit"], errors);
		}

		function parseRoaming(location, value, errors) {
			function parseVariant0(location, value, errors) {
				value = instantiateInterfaceSsidRoaming(location, value, errors);

				return value;
			}

			function parseVariant1(location, value, errors) {
				if (type(value) != "bool")
					push(errors, [ location, "must be of type boolean" ]);

				return value;
			}

			let success = 0, tryval, tryerr, vvalue = null, verrors = [];

			tryerr = [];
			tryval = parseVariant0(location, value, tryerr);
			if (!length(tryerr)) {
				if (type(vvalue) == "object" && type(tryval) == "object")
					vvalue = { ...vvalue, ...tryval };
				else
					vvalue = tryval;

				success++;
			}
			else {
				push(verrors, join(" and\n", map(tryerr, err => "\t - " + err[1])));
			}

			tryerr = [];
			tryval = parseVariant1(location, value, tryerr);
			if (!length(tryerr)) {
				if (type(vvalue) == "object" && type(tryval) == "object")
					vvalue = { ...vvalue, ...tryval };
				else
					vvalue = tryval;

				success++;
			}
			else {
				push(verrors, join(" and\n", map(tryerr, err => "\t - " + err[1])));
			}

			if (success == 0) {
				if (length(verrors))
					push(errors, [ location, "must match at least one of the following constraints:\n" + join("\n- or -\n", verrors) ]);
				else
					push(errors, [ location, "must match only one variant" ]);
				return null;
			}

			value = vvalue;

			return value;
		}

		if (exists(value, "roaming")) {
			obj.roaming = parseRoaming(location + "/roaming", value["roaming"], errors);
		}

		if (exists(value, "radius")) {
			obj.radius = instantiateInterfaceSsidRadius(location + "/radius", value["radius"], errors);
		}

		if (exists(value, "access-control-list")) {
			obj.access_control_list = instantiateInterfaceSsidAcl(location + "/access-control-list", value["access-control-list"], errors);
		}

		function parseHostapdBssRaw(location, value, errors) {
			if (type(value) == "array") {
				function parseItem(location, value, errors) {
					if (type(value) != "string")
						push(errors, [ location, "must be of type string" ]);

					return value;
				}

				return map(value, (item, i) => parseItem(location + "/" + i, item, errors));
			}

			if (type(value) != "array")
				push(errors, [ location, "must be of type array" ]);

			return value;
		}

		if (exists(value, "hostapd-bss-raw")) {
			obj.hostapd_bss_raw = parseHostapdBssRaw(location + "/hostapd-bss-raw", value["hostapd-bss-raw"], errors);
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

function instantiateInterfaceTunnelMeshBatman(location, value, errors) {
	for (let require in [ "kmod-batman-adv" ])
		if (!length(fs.glob("/usr/lib/opkg/info/" + require + ".control")) &&
		    !length(fs.glob("/lib/apk/packages/" + require + ".list")))
			push(errors, [ location, "is missing system dependency: " + require]);
	if (type(value) == "object") {
		let obj = {};

		function parseProto(location, value, errors) {
			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			if (value != "mesh-batman")
				push(errors, [ location, "must have value \"mesh-batman\"" ]);

			return value;
		}

		if (exists(value, "proto")) {
			obj.proto = parseProto(location + "/proto", value["proto"], errors);
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

function instantiateInterfaceTunnel(location, value, errors) {
	function parseVariant0(location, value, errors) {
		value = instantiateInterfaceTunnelMeshBatman(location, value, errors);

		return value;
	}

	let success = 0, tryval, tryerr, vvalue = null, verrors = [];

	tryerr = [];
	tryval = parseVariant0(location, value, tryerr);
	if (!length(tryerr)) {
		if (type(vvalue) == "object" && type(tryval) == "object")
			vvalue = { ...vvalue, ...tryval };
		else
			vvalue = tryval;

		success++;
	}
	else {
		push(verrors, join(" and\n", map(tryerr, err => "\t - " + err[1])));
	}

	if (success != 1) {
		if (length(verrors))
			push(errors, [ location, "must match exactly one of the following constraints:\n" + join("\n- or -\n", verrors) ]);
		else
			push(errors, [ location, "must match only one variant" ]);
		return null;
	}

	value = vvalue;

	return value;
}

function instantiateInterface(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		function parseRole(location, value, errors) {
			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			if (!(value in [ "upstream", "downstream" ]))
				push(errors, [ location, "must be one of \"upstream\" or \"downstream\"" ]);

			return value;
		}

		if (exists(value, "role")) {
			obj.role = parseRole(location + "/role", value["role"], errors);
		}

		function parseIsolateHosts(location, value, errors) {
			if (type(value) != "bool")
				push(errors, [ location, "must be of type boolean" ]);

			return value;
		}

		if (exists(value, "isolate-hosts")) {
			obj.isolate_hosts = parseIsolateHosts(location + "/isolate-hosts", value["isolate-hosts"], errors);
		}

		function parseMetric(location, value, errors) {
			if (type(value) in [ "int", "double" ]) {
				if (value > 4294967295)
					push(errors, [ location, "must be lower than or equal to 4294967295" ]);

				if (value < 0)
					push(errors, [ location, "must be bigger than or equal to 0" ]);

			}

			if (type(value) != "int")
				push(errors, [ location, "must be of type integer" ]);

			return value;
		}

		if (exists(value, "metric")) {
			obj.metric = parseMetric(location + "/metric", value["metric"], errors);
		}

		function parseMtu(location, value, errors) {
			if (type(value) in [ "int", "double" ]) {
				if (value > 1500)
					push(errors, [ location, "must be lower than or equal to 1500" ]);

				if (value < 1280)
					push(errors, [ location, "must be bigger than or equal to 1280" ]);

			}

			if (type(value) != "int")
				push(errors, [ location, "must be of type integer" ]);

			return value;
		}

		if (exists(value, "mtu")) {
			obj.mtu = parseMtu(location + "/mtu", value["mtu"], errors);
		}

		function parseServices(location, value, errors) {
			if (type(value) == "array") {
				function parseItem(location, value, errors) {
					if (type(value) != "string")
						push(errors, [ location, "must be of type string" ]);

					return value;
				}

				return map(value, (item, i) => parseItem(location + "/" + i, item, errors));
			}

			if (type(value) != "array")
				push(errors, [ location, "must be of type array" ]);

			return value;
		}

		if (exists(value, "services")) {
			obj.services = parseServices(location + "/services", value["services"], errors);
		}

		if (exists(value, "vlan")) {
			obj.vlan = instantiateInterfaceVlan(location + "/vlan", value["vlan"], errors);
		}

		if (exists(value, "bridge")) {
			obj.bridge = instantiateInterfaceBridge(location + "/bridge", value["bridge"], errors);
		}

		function parsePorts(location, value, errors) {
			if (type(value) == "object") {
				let obj = {};

				for (let name, object in value)
					if (match(name, regexp(name)))
						obj[name] = instantiateInterfacePorts(location + "/" + name, object, errors);

				return obj;
			}

			if (type(value) != "object")
				push(errors, [ location, "must be of type object" ]);

			return value;
		}

		if (exists(value, "ports")) {
			obj.ports = parsePorts(location + "/ports", value["ports"], errors);
		}

		function parseIeee8021xPorts(location, value, errors) {
			if (type(value) == "object") {
				let obj = {};

				for (let name, object in value)
					if (match(name, regexp(name)))
						obj[name] = instantiateInterfacePorts(location + "/" + name, object, errors);

				return obj;
			}

			if (type(value) != "object")
				push(errors, [ location, "must be of type object" ]);

			return value;
		}

		if (exists(value, "ieee8021x-ports")) {
			obj.ieee8021x_ports = parseIeee8021xPorts(location + "/ieee8021x-ports", value["ieee8021x-ports"], errors);
		}

		if (exists(value, "ipv4")) {
			obj.ipv4 = instantiateInterfaceIpv4(location + "/ipv4", value["ipv4"], errors);
		}

		if (exists(value, "ipv6")) {
			obj.ipv6 = instantiateInterfaceIpv6(location + "/ipv6", value["ipv6"], errors);
		}

		function parseSsids(location, value, errors) {
			if (type(value) == "object") {
				let obj = {};

				for (let name, object in value)
					if (match(name, regexp(name)))
						obj[name] = instantiateInterfaceSsid(location + "/" + name, object, errors);

				return obj;
			}

			if (type(value) != "object")
				push(errors, [ location, "must be of type object" ]);

			return value;
		}

		if (exists(value, "ssids")) {
			obj.ssids = parseSsids(location + "/ssids", value["ssids"], errors);
		}

		if (exists(value, "tunnel")) {
			obj.tunnel = instantiateInterfaceTunnel(location + "/tunnel", value["tunnel"], errors);
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

function instantiateServiceSsh(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		function parsePort(location, value, errors) {
			if (type(value) in [ "int", "double" ]) {
				if (value > 65535)
					push(errors, [ location, "must be lower than or equal to 65535" ]);

			}

			if (type(value) != "int")
				push(errors, [ location, "must be of type integer" ]);

			return value;
		}

		if (exists(value, "port")) {
			obj.port = parsePort(location + "/port", value["port"], errors);
		}
		else {
			obj.port = 22;
		}

		function parseAuthorizedKeys(location, value, errors) {
			if (type(value) == "array") {
				function parseItem(location, value, errors) {
					if (type(value) != "string")
						push(errors, [ location, "must be of type string" ]);

					return value;
				}

				return map(value, (item, i) => parseItem(location + "/" + i, item, errors));
			}

			if (type(value) != "array")
				push(errors, [ location, "must be of type array" ]);

			return value;
		}

		if (exists(value, "authorized-keys")) {
			obj.authorized_keys = parseAuthorizedKeys(location + "/authorized-keys", value["authorized-keys"], errors);
		}

		function parsePasswordAuthentication(location, value, errors) {
			if (type(value) != "bool")
				push(errors, [ location, "must be of type boolean" ]);

			return value;
		}

		if (exists(value, "password-authentication")) {
			obj.password_authentication = parsePasswordAuthentication(location + "/password-authentication", value["password-authentication"], errors);
		}
		else {
			obj.password_authentication = true;
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

function instantiateServiceMdns(location, value, errors) {
	try {
		let module = require('ureader.schemaServiceMdns');
		return module.validate(location, value, errors);
	} catch(e) {
		push(errors, [ location, "is missing its module. Please install uconfig-mod-mdns."  ]);
	}
}

function instantiateServiceLldp(location, value, errors) {
	try {
		let module = require('ureader.schemaServiceLldp');
		return module.validate(location, value, errors);
	} catch(e) {
		push(errors, [ location, "is missing its module. Please install uconfig-mod-lldp."  ]);
	}
}

function instantiateServiceNtp(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		function parseServers(location, value, errors) {
			if (type(value) == "array") {
				function parseItem(location, value, errors) {
					if (type(value) == "string") {
						if (!matchUcHost(value))
							push(errors, [ location, "must be a valid hostname or IP address" ]);

					}

					if (type(value) != "string")
						push(errors, [ location, "must be of type string" ]);

					return value;
				}

				return map(value, (item, i) => parseItem(location + "/" + i, item, errors));
			}

			if (type(value) != "array")
				push(errors, [ location, "must be of type array" ]);

			return value;
		}

		if (exists(value, "servers")) {
			obj.servers = parseServers(location + "/servers", value["servers"], errors);
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

function instantiateServiceLog(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		function parseHost(location, value, errors) {
			if (type(value) == "string") {
				if (!matchUcHost(value))
					push(errors, [ location, "must be a valid hostname or IP address" ]);

			}

			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			return value;
		}

		if (exists(value, "host")) {
			obj.host = parseHost(location + "/host", value["host"], errors);
		}

		function parsePort(location, value, errors) {
			if (type(value) in [ "int", "double" ]) {
				if (value > 65535)
					push(errors, [ location, "must be lower than or equal to 65535" ]);

				if (value < 100)
					push(errors, [ location, "must be bigger than or equal to 100" ]);

			}

			if (type(value) != "int")
				push(errors, [ location, "must be of type integer" ]);

			return value;
		}

		if (exists(value, "port")) {
			obj.port = parsePort(location + "/port", value["port"], errors);
		}

		function parseProto(location, value, errors) {
			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			if (!(value in [ "tcp", "udp" ]))
				push(errors, [ location, "must be one of \"tcp\" or \"udp\"" ]);

			return value;
		}

		if (exists(value, "proto")) {
			obj.proto = parseProto(location + "/proto", value["proto"], errors);
		}
		else {
			obj.proto = "udp";
		}

		function parseSize(location, value, errors) {
			if (type(value) in [ "int", "double" ]) {
				if (value < 32)
					push(errors, [ location, "must be bigger than or equal to 32" ]);

			}

			if (type(value) != "int")
				push(errors, [ location, "must be of type integer" ]);

			return value;
		}

		if (exists(value, "size")) {
			obj.size = parseSize(location + "/size", value["size"], errors);
		}
		else {
			obj.size = 1000;
		}

		function parsePriority(location, value, errors) {
			if (type(value) in [ "int", "double" ]) {
				if (value < 0)
					push(errors, [ location, "must be bigger than or equal to 0" ]);

			}

			if (type(value) != "int")
				push(errors, [ location, "must be of type integer" ]);

			return value;
		}

		if (exists(value, "priority")) {
			obj.priority = parsePriority(location + "/priority", value["priority"], errors);
		}
		else {
			obj.priority = 7;
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

function instantiateServiceIeee8021x(location, value, errors) {
	try {
		let module = require('ureader.schemaServiceIeee8021x');
		return module.validate(location, value, errors);
	} catch(e) {
		push(errors, [ location, "is missing its module. Please install uconfig-mod-ieee8021x."  ]);
	}
}

function instantiateService(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		if (exists(value, "ssh")) {
			obj.ssh = instantiateServiceSsh(location + "/ssh", value["ssh"], errors);
		}

		if (exists(value, "mdns")) {
			obj.mdns = instantiateServiceMdns(location + "/mdns", value["mdns"], errors);
		}

		if (exists(value, "lldp")) {
			obj.lldp = instantiateServiceLldp(location + "/lldp", value["lldp"], errors);
		}

		if (exists(value, "ntp")) {
			obj.ntp = instantiateServiceNtp(location + "/ntp", value["ntp"], errors);
		}

		if (exists(value, "log")) {
			obj.log = instantiateServiceLog(location + "/log", value["log"], errors);
		}

		if (exists(value, "ieee8021x")) {
			obj.ieee8021x = instantiateServiceIeee8021x(location + "/ieee8021x", value["ieee8021x"], errors);
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

function newUConfigState(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		function parseStrict(location, value, errors) {
			if (type(value) != "bool")
				push(errors, [ location, "must be of type boolean" ]);

			return value;
		}

		if (exists(value, "strict")) {
			obj.strict = parseStrict(location + "/strict", value["strict"], errors);
		}
		else {
			obj.strict = false;
		}

		function parseUuid(location, value, errors) {
			if (type(value) != "int")
				push(errors, [ location, "must be of type integer" ]);

			return value;
		}

		if (exists(value, "uuid")) {
			obj.uuid = parseUuid(location + "/uuid", value["uuid"], errors);
		}

		if (exists(value, "unit")) {
			obj.unit = instantiateUnit(location + "/unit", value["unit"], errors);
		}

		if (exists(value, "globals")) {
			obj.globals = instantiateGlobals(location + "/globals", value["globals"], errors);
		}

		if (exists(value, "ethernet")) {
			obj.ethernet = instantiateEthernet(location + "/ethernet", value["ethernet"], errors);
		}

		function parseCountryCode(location, value, errors) {
			if (type(value) == "string") {
				if (length(value) > 2)
					push(errors, [ location, "must be at most 2 characters long" ]);

				if (length(value) < 2)
					push(errors, [ location, "must be at least 2 characters long" ]);

			}

			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			return value;
		}

		if (exists(value, "country-code")) {
			obj.country_code = parseCountryCode(location + "/country-code", value["country-code"], errors);
		}

		function parseRadios(location, value, errors) {
			if (type(value) == "object") {
				let obj = {};

				for (let name, object in value)
					if (match(name, regexp(name)))
						obj[name] = instantiateRadio(location + "/" + name, object, errors);

				return obj;
			}

			if (type(value) != "object")
				push(errors, [ location, "must be of type object" ]);

			return value;
		}

		if (exists(value, "radios")) {
			obj.radios = parseRadios(location + "/radios", value["radios"], errors);
		}

		function parseInterfaces(location, value, errors) {
			if (type(value) == "object") {
				let obj = {};

				for (let name, object in value)
					if (match(name, regexp(name)))
						obj[name] = instantiateInterface(location + "/" + name, object, errors);

				return obj;
			}

			if (type(value) != "object")
				push(errors, [ location, "must be of type object" ]);

			return value;
		}

		if (exists(value, "interfaces")) {
			obj.interfaces = parseInterfaces(location + "/interfaces", value["interfaces"], errors);
		}

		if (exists(value, "services")) {
			obj.services = instantiateService(location + "/services", value["services"], errors);
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

export function validate(value, errors) {
	let err = [];
	let res = newUConfigState("", value, err);
	if (errors) push(errors, ...map(err, e => "[E] (In " + e[0] + ") Value " + e[1]));
	return length(err) ? null : res;
};
