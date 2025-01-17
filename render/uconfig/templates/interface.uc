{%
	let has_downstream_relays = false;

	/* skip interfaces previously marked as conflicting */
	if (interface.conflicting) {
		warn('Skipping conflicting interface declaration');
		return;
	}

	/* work out the bridge vlan of this interface */
	let this_vid = interface.vlan.id || interface.vlan.dyn_id;

	/* make sure that the vlan is unique */
	for (let name, other_interface in state.interfaces) {
		/* skip if this is the same interface */
		if (other_interface == interface)
			continue;

		/* if the 'other' interface has no wired ports and a single ssid, skip it */
		if (!other_interface.ports && length(interface.ssids) == 1)
			continue;

		let other_vid = other_interface.vlan.id || '';

		/* if this 'this' and 'other' interface have the same role and vlan, mark 'other' as conflicting */
		if (interface.role === other_interface.role && this_vid === other_vid) {
			warn('Multiple interfaces with same role and VLAN ID defined, ignoring conflicting interface');
			other_interface.conflicting = true;
			continue;
		}

		/* if 'this' is an upstream and 'other' is a downstream interface with ipv6, relay needs to be enabled */
		if (other_interface.role == 'downstream' &&
		    other_interface.ipv6 &&
		    other_interface.ipv6.dhcpv6 &&
		    other_interface.ipv6.dhcpv6.mode == 'relay')
		    has_downstream_relays = true;
	}

	/* check if a downstream interface with a vlan has a matching upstream interface */
	if (ethernet.has_vlan(interface) && interface.role == 'downstream' &&
	    index(vlans_upstream, this_vid) < 0) {
		warn('Trying to create a downstream interface with a VLAN ID, without matching upstream interface.');
		return;
	}

	/* reject static config that has no subnet */
	if (interface.role == 'upstream' && interface.ipv4?.addressing == 'static')
		if (!interface.ipv4?.subnet || !interface.ipv4?.use_dns || !interface.ipv4?.gateway)
			die('invalid static interface settings');

	/* resolve the IPv4 auto prefix */
	if (wildcard(interface.ipv4?.subnet, 'auto/*')) {
		try {
			interface.ipv4.subnet = ipcalc.generate_prefix(state, interface.ipv4.subnet, false);
		}
		catch (e) {
			warn('Unable to allocate a suitable IPv4 prefix: %s, ignoring interface', e);
			return;
		}
	}

	/* resolve the IPv6 auto prefix */
	if (wildcard(interface.ipv6?.subnet, 'auto/*')) {
		try {
			interface.ipv6.subnet = ipcalc.generate_prefix(state, interface.ipv6.subnet, true);
		}
		catch (e) {
			warn('Unable to allocate a suitable IPv6 prefix: %s, ignoring interface', e);
			return;
		}
	}

	/* gather related BSS modes and ethernet ports */
	let bss_modes = map(interface.ssids, ssid => ssid.bss_mode);
	let eth_ports = ethernet.lookup_by_interface_vlan(interface);
	let dot1x_ports = ethernet.lookup_by_select_ports(interface.ieee8021x_ports);
	ethernet.assign_port_role(eth_ports, interface.role);

	/* if at least one station mode SSID is part of this interface then we must
	 * not bridge at all. Having any other SSID or any number of matching ethernet
	 * ports in such a case is a semantic error
	 */
	if ('sta' in bss_modes && (length(eth_ports) > 0 || length(bss_modes) > 1)) {
		warn('Station mode SSIDs cannot be bridged with ethernet ports or other SSIDs, ignoring interface');

		return;
	}

	/* compute unique logical name and netdev name to use */
	let name = interface.name;
	let bridgedev = interface.bridge_name;
	let netdev = ethernet.calculate_name(interface);
	let network = name;

	/* determine the IPv4 and IPv6 configuration modes and figure out if we
	 * can set them both in a single interface (automatic) or whether we need
	 * two logical interfaces due to different protocols.
	 */
	let ipv4_mode = interface.ipv4?.addressing || 'none';
	let ipv6_mode = interface.ipv6?.addressing || 'none';

	/* if no metric is defined explicitly, any upstream interfaces will default
	 * to 5 and downstream interfaces will default to 10
	 */
	if (!interface.metric)
		interface.metric = (interface.role == 'upstream') ? 5 : 10;

	/* if this interface is a tunnel, we need to create the interface in a different way */
	let tunnel_proto = interface.tunnel?.proto || '';

	/**
	 * generate the actual UCI sections
	 */

	/* some tunnel overlays require two additional interface sections */
	if (tunnel_proto in [ 'mesh-batman' ])
		include('interface/' + tunnel_proto + '.uc', { interface, name, eth_ports, location, netdev, ipv4_mode, ipv6_mode, this_vid });

	if (!interface.ports && length(interface.ssids) == 1 && !tunnel_proto)
		/* interfaces with a single ssid and no tunnel do not need a bridge */
		netdev = '';
	else
		/* anything else requires a bridge-vlan */
		include('interface/bridge-vlan.uc', { interface, netdev, eth_ports, this_vid, bridgedev });

	/* generate UCI common to all interfaces */
	include('interface/common.uc', {
		name, this_vid, netdev,
		ipv4_mode, ipv4: interface.ipv4 || {},
		ipv6_mode, ipv6: interface.ipv6 || {}
	});

	/* setup the interfaces firewalling */
	include('interface/firewall.uc', { name, ipv4_mode, ipv6_mode, networks: false });

	/* setup 802.1x ports */
	if (length(dot1x_ports))
		include('interface/ieee8021x.uc', { dot1x_ports, interface, eth_ports, this_vid });

	/* setup the DHCPv4/6 server */
	if (interface.ipv4 || interface.ipv6) {
		include('interface/dhcp.uc', {
			ipv4: interface.ipv4 || {},
			ipv6: interface.ipv6 || {},
			has_downstream_relays
		});
	}

	/* configure WiFi */
	let count = 0;
	for (let i, ssid in interface.ssids) {
		/* 'wds-repeater' is a place-holder, if selected create two BSS */
		let modes = (ssid.bss_mode == 'wds-repeater') ?
			[ 'wds-sta', 'wds-ap' ] : [ ssid.bss_mode ];
		for (let mode in modes) {
			include('interface/ssid.uc', {
				location: location + '/ssids/' + i,
				ssid: { ...ssid, bss_mode: mode },
				count: count++,
				name,
				network
			});
		}
	}
%}
