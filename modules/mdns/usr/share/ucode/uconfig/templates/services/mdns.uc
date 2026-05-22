{%
	// Helper functions
	function has_mdns_service() {
		return services.is_present("umdns");
	}

	function get_mdns_interfaces() {
		let interfaces = services.lookup_interfaces("mdns");
		let fingerprint = services.lookup_interfaces("fingerprint");

		return uniq([ ...interfaces, ...fingerprint ]);
	}

	// Configuration generation functions
	function generate_hostname_file(mdns) {
		let hosts = {};

		for (let hostname in mdns?.additional_hostnames || [])
			hosts[hostname + ".local"] = {
				hostname: hostname + ".local"
			};

		if (length(hosts))
			fs.writefile('/etc/umdns/uconfig.json', hosts);
	}

	function generate_umdns_config(interfaces) {
		let output = [];

		uci_comment(output, '### generate umdns configuration');
		uci_section(output, 'umdns umdns');
		uci_set_boolean(output, 'umdns.@umdns[-1].jail', true);

		for (let interface in interfaces)
			uci_list_string(output, 'umdns.@umdns[-1].network', interface.name);

		return uci_output(output);
	}

	function generate_mdns_firewall_rules(interfaces) {
		if (!length(interfaces))
			return '';

		let output = [];

		uci_comment(output, '### generate mdns firewall rules');

		for (let interface in interfaces) {
			let name = interface.name;

			uci_section(output, 'firewall rule');
			uci_set_string(output, 'firewall.@rule[-1].name', `Allow-mdns-${name}`);
			uci_set_string(output, 'firewall.@rule[-1].src', name);
			uci_set_string(output, 'firewall.@rule[-1].dest_port', 5353);
			uci_set_string(output, 'firewall.@rule[-1].proto', 'udp');
			uci_set_string(output, 'firewall.@rule[-1].target', 'ACCEPT');
		}

		return uci_output(output);
	}

	// Main logic
	if (!has_mdns_service())
		return;

	let interfaces = get_mdns_interfaces();
	let enable = length(interfaces) > 0;

	services.set_enabled("umdns", enable ? 'restart' : false);

	if (!enable)
		return;

	let conflict = port.claim('mdns', 5353, 'udp', interfaces);
	if (conflict) {
		state.strict = true;
		error('service port conflict: mdns port 5353/udp overlaps with %s on interface(s) %s',
		      conflict.service, join(', ', conflict.interfaces));
	}

	generate_hostname_file(mdns);
%}

## Configure MDNS
{{ generate_umdns_config(interfaces) }}
{{ generate_mdns_firewall_rules(interfaces) }}
