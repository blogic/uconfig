{%
	/* reject the config if there is no valid UUID */
	if (!state.uuid) {
		state.strict = true;
		error('Configuration must contain a valid UUID. Rejecting whole file');
		return;
	}

	/* reject the config if there is no valid upstream configuration */
	let upstream;
	for (let i, interface in state.interfaces) {
		if (interface.role != 'upstream')
			continue;
		upstream = interface;
	}

	if (!upstream) {
		state.strict = true;
		error('Configuration must contain at least one valid upstream interface. Rejecting whole file');
		return;
	}

	// reject config if a wired port is used twice in un-tagged mode
	let wan_ports = [];
	for (let i, interface in state.interfaces) {
		if (interface.role != 'upstream')
			continue;
		let eth_ports = ethernet.lookup_by_interface_vlan(interface);
		for (let port in keys(eth_ports)) {
			if (ethernet.port_vlan(interface, eth_ports[port]))
				continue;
			if (port in wan_ports) {
				state.strict = true;
				error('duplicate usage of un-tagged ports: ' + port);
				return;
			}
			push(wan_ports, port);
		}
	}

	/* reserve all ieee8021x ports */
	for (let i, interface in state.interfaces) {
		let ports = ethernet.lookup_by_select_ports(interface.ieee8021x_ports);
		for (let port in ports)
			ethernet.reserve_port(port);
	}

	let bridges = {};
	for (let name, interface in state.interfaces) {
		interface.name = name;

		let brname = "sw";
		if (interface.bridge && interface.bridge.name)
			brname = interface.bridge.name;
		interface.bridge_name = brname;

		let br = bridges[brname];
		if (!br) {
			br = bridges[brname] = {
				vlans: [],
				index: 0,
				vid: 4090,
			};
			tryinclude('bridge.uc', { name: brname });
		}

		if (ethernet.has_vlan(interface))
			push(br.vlans, interface.vlan.id);
		else
			interface.vlan = { id: 0 };

		interface.index = br.index++;
	}

	/* dynamically assigned vlans start at 4090 counting backwards */
	function next_free_vid(br) {
		while (br.vid in br.vlans)
			br.vid--;
		return br.vid--;
	}

	/* dynamically assign vlan ids to all interfaces that have none yet */
	for (let i, interface in state.interfaces) {
		let br = bridges[interface.bridge_name];
		if (!interface.vlan.id)
			interface.vlan.dyn_id = next_free_vid(br);
	}

	/* check if there is a system default for the country code */
	if (board.wlan.defaults)
		if (board.wlan.defaults.country) {
			warn('overriding country code with system default\n');
			state.country_code = board.wlan.defaults.country;
		}

	/* force auto channel if there are any sta interfaces on the radio */
	for (let i, radio in state.radios) {
		if (!radio.channel || radio.channel == 'auto')
			continue;
		for (let j, iface in state.interfaces)
			for (let s, ssid in iface.ssids)
		if (ssid.bss_mode in [ 'sta', 'wds-sta', 'wds-repeater' ]) {
			warn('Forcing Auto-Channel as a STA interface is present');
			delete radio.channel;
		}
	}

	/* render the basic UCI setup */
	include('base.uc');

	/* render the unit configuration */
	if (!state.unit)
		state.unit = {
			leds_active: true,
			tty_login: false,
			password: false,
		};
	include('unit.uc', { location: '/unit', unit: state.unit });

	state.services ??= {};
	for (let service in services.lookup_services())
		tryinclude('services/' + service + '.uc', {
			location: '/services/' + service,
			[service]: state.services[service] || {}
		});

	/* render the ethernet port configuration */
	tryinclude('ethernet.uc', { location: '/ethernet/', wan_ports });

	/* render the wireless PHY configuration */
	for (let phy_name, radio in state.radios)
		tryinclude('radio.uc', { location: '/radios/' + phy_name, phy_name, radio });

	/* render the logical interface configuration (includes SSIDs) */
	function iterate_interfaces(role) {
		for (let i, interface in state.interfaces) {
			if (interface.role != role)
				continue;
			include('interface.uc', { location: '/interfaces/' + i, interface, vlans_upstream });
		}
	}

	iterate_interfaces("upstream");
	iterate_interfaces("downstream");
%}
