{%
	if (!services.is_present("ufp"))
		return;

	let interfaces = services.lookup_interfaces("fingerprint");
	let enable = !!length(interfaces);

	services.set_enabled("ufp", enable);
	services.set_enabled("dhcpsnoop", enable);
%}

# DHCP Snooping configuration
add dhcpsnoop snooping
set dhcpsnoop.@snooping[-1].enable='1'
{%
	let names = [];
	for (let interface in interfaces)
		for (let name in ethernet.lookup_by_interface_vlan(interface))
			push(names, name);
	for (let name in uniq(names)):
%}
add dhcpsnoop device
set dhcpsnoop.@device[-1].name={{ s(name) }}
set dhcpsnoop.@device[-1].ingress=1
set dhcpsnoop.@device[-1].egress=1
{%      endfor %}
