{%
	function generate_ucoord_ui_firewall_rules(interfaces) {
		if (!length(interfaces))
			return '';

		let output = [];

		uci_comment(output, '### generate ucoord-ui firewall rules');

		for (let interface in interfaces) {
			let name = interface.name;

			uci_section(output, 'firewall rule');
			uci_set_string(output, 'firewall.@rule[-1].name', `Allow-ucoord-ui-http-${name}`);
			uci_set_string(output, 'firewall.@rule[-1].src', name);
			uci_set_string(output, 'firewall.@rule[-1].dest_port', '80');
			uci_set_string(output, 'firewall.@rule[-1].proto', 'tcp');
			uci_set_string(output, 'firewall.@rule[-1].target', 'ACCEPT');
		}

		return uci_output(output);
	}

	let interfaces = services.lookup_interfaces("ucoord-ui");
	let enable = length(interfaces) > 0;
	services.set_enabled("ucoord-ui", enable);

	if (!enable)
		return;
%}

## Configure ucoord-ui firewall
{{ generate_ucoord_ui_firewall_rules(interfaces) }}
