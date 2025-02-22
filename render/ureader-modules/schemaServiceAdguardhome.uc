function moduleServiceAdguardhome(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		function parseWebuiPort(location, value, errors) {
			if (type(value) in [ "int", "double" ]) {
				if (value > 65535)
					push(errors, [ location, "must be lower than or equal to 65535" ]);

				if (value < 100)
					push(errors, [ location, "must be bigger than or equal to 100" ]);

			}

			if (!(type(value) in [ "int", "double" ]))
				push(errors, [ location, "must be of type number" ]);

			return value;
		}

		if (exists(value, "webui-port")) {
			obj.webui_port = parseWebuiPort(location + "/webui-port", value["webui-port"], errors);
		}
		else {
			obj.webui_port = 3000;
		}

		function parseDnsIntercept(location, value, errors) {
			if (type(value) != "bool")
				push(errors, [ location, "must be of type boolean" ]);

			return value;
		}

		if (exists(value, "dns-intercept")) {
			obj.dns_intercept = parseDnsIntercept(location + "/dns-intercept", value["dns-intercept"], errors);
		}

		function parseServers(location, value, errors) {
			if (type(value) == "array") {
				function parseItem(location, value, errors) {
					if (type(value) == "string") {
						if (!matchUcIp(value))
							push(errors, [ location, "must be a valid IPv4 or IPv6 address" ]);

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

return {
	validate: function(location, value, errors) {
		return moduleServiceAdguardhome(location, value, errors);
	}
};
