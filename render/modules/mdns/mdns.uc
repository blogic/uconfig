{%-
	if (!services.is_present("umdns"))
		return;

	let interfaces = services.lookup_interfaces("mdns");
	let fingerprint = services.lookup_interfaces("fingerprint");
	let enable = length(interfaces) + length(fingerprint);
	services.set_enabled("umdns", !!enable ? 'restart' : false);
	if (!enable)
		return;

	let hosts = {
		[ global.capabilities.serial + ".local" ]: {
			"hostname": global.capabilities.serial + ".local"
		}
	};
	for (let hostname in mdns?.additional_hostnames || [])
		hosts[hostname + ".local"] = {
			hostname: hostname + ".local" 
		};
	fs.writefile('/etc/umdns/uconfig.json', hosts);
%}

# Configure MDNS
{%	for (let interface in uniq([ ...interfaces, ...fingerprint ])): %}
add_list umdns.@umdns[0].network={{ s(interface.name) }}
{%	endfor %}
