function moduleServiceWebui(location, value, errors) {
	if (type(value) == "object") {
		let obj = {};

		function parseTlsOnly(location, value, errors) {
			if (type(value) != "bool")
				push(errors, [ location, "must be of type boolean" ]);

			return value;
		}

		if (exists(value, "tls-only")) {
			obj.tls_only = parseTlsOnly(location + "/tls-only", value["tls-only"], errors);
		}

		return obj;
	}

	if (type(value) != "object")
		push(errors, [ location, "must be of type object" ]);

	return value;
}

return {
	validate: function(location, value, errors) {
		return moduleServiceWebui(location, value, errors);
	}
};
