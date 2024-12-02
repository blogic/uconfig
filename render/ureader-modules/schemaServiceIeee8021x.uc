function moduleServiceIeee8021x(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		function parseMode(location, value, errors) {
			if (type(value) != "string")
				push(errors, [ location, "must be of type string" ]);

			if (!(value in [ "radius", "user" ]))
				push(errors, [ location, "must be one of \"radius\" or \"user\"" ]);

			return value;
		}

		if (exists(value, "mode")) {
			obj.mode = parseMode(location + "/mode", value["mode"], errors);
		}

		function parseUsers(location, value, errors) {
			if (type(value) == "array") {
				return map(value, (item, i) => instantiateConfigurationsRadiusServersLocalUser(location + "/" + i, item, errors));
			}

			if (type(value) != "array")
				push(errors, [ location, "must be of type array" ]);

			return value;
		}

		if (exists(value, "users")) {
			obj.users = parseUsers(location + "/users", value["users"], errors);
		}

		function parseRadius(location, value, errors) {
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

				function parseAuthServerAddr(location, value, errors) {
					if (type(value) != "string")
						push(errors, [ location, "must be of type string" ]);

					return value;
				}

				if (exists(value, "auth-server-addr")) {
					obj.auth_server_addr = parseAuthServerAddr(location + "/auth-server-addr", value["auth-server-addr"], errors);
				}

				function parseAuthServerPort(location, value, errors) {
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

				if (exists(value, "auth-server-port")) {
					obj.auth_server_port = parseAuthServerPort(location + "/auth-server-port", value["auth-server-port"], errors);
				}

				function parseAuthServerSecret(location, value, errors) {
					if (type(value) != "string")
						push(errors, [ location, "must be of type string" ]);

					return value;
				}

				if (exists(value, "auth-server-secret")) {
					obj.auth_server_secret = parseAuthServerSecret(location + "/auth-server-secret", value["auth-server-secret"], errors);
				}

				function parseAcctServerAddr(location, value, errors) {
					if (type(value) != "string")
						push(errors, [ location, "must be of type string" ]);

					return value;
				}

				if (exists(value, "acct-server-addr")) {
					obj.acct_server_addr = parseAcctServerAddr(location + "/acct-server-addr", value["acct-server-addr"], errors);
				}

				function parseAcctServerPort(location, value, errors) {
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

				if (exists(value, "acct-server-port")) {
					obj.acct_server_port = parseAcctServerPort(location + "/acct-server-port", value["acct-server-port"], errors);
				}

				function parseAcctServerSecret(location, value, errors) {
					if (type(value) != "string")
						push(errors, [ location, "must be of type string" ]);

					return value;
				}

				if (exists(value, "acct-server-secret")) {
					obj.acct_server_secret = parseAcctServerSecret(location + "/acct-server-secret", value["acct-server-secret"], errors);
				}

				function parseCoaServerAddr(location, value, errors) {
					if (type(value) != "string")
						push(errors, [ location, "must be of type string" ]);

					return value;
				}

				if (exists(value, "coa-server-addr")) {
					obj.coa_server_addr = parseCoaServerAddr(location + "/coa-server-addr", value["coa-server-addr"], errors);
				}

				function parseCoaServerPort(location, value, errors) {
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

				if (exists(value, "coa-server-port")) {
					obj.coa_server_port = parseCoaServerPort(location + "/coa-server-port", value["coa-server-port"], errors);
				}

				function parseCoaServerSecret(location, value, errors) {
					if (type(value) != "string")
						push(errors, [ location, "must be of type string" ]);

					return value;
				}

				if (exists(value, "coa-server-secret")) {
					obj.coa_server_secret = parseCoaServerSecret(location + "/coa-server-secret", value["coa-server-secret"], errors);
				}

				function parseMacAddressBypass(location, value, errors) {
					if (type(value) != "bool")
						push(errors, [ location, "must be of type boolean" ]);

					return value;
				}

				if (exists(value, "mac-address-bypass")) {
					obj.mac_address_bypass = parseMacAddressBypass(location + "/mac-address-bypass", value["mac-address-bypass"], errors);
				}

				return obj;
			}

			if (type(value) != "object")
				push(errors, [ location, "must be of type object" ]);

			return value;
		}

		if (exists(value, "radius")) {
			obj.radius = parseRadius(location + "/radius", value["radius"], errors);
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

return {
	validate: function(location, value, errors) {
		return moduleServiceIeee8021x(location, value, errors);
	}
};
