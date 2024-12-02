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
