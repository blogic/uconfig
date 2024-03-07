{%-
	if (!services.is_present("unetd"))
		return;

	let unet = json(fs.readfile('/etc/uconfig/data/unetd.json') || '{}');
	let interfaces = services.lookup_interfaces("unet");
	let enable = unet && interfaces;
	
	services.set_enabled("unetd", enable);
	if (!enable)
		return;

	let local_network = [];	
	for (let interface in interfaces)
		if (length(ethernet.calculate_names(interface)) >= 2)
			push(local_network, interface.name + '_4');
		else
			push(local_network, interface.name);

	for (let name, config in unet):
%}

add firewall zone
set firewall.@zone[-1].name='unet'
set firewall.@zone[-1].input='ACCEPT'
set firewall.@zone[-1].output='ACCEPT'
set firewall.@zone[-1].forward='REJECT'

set network.{{ name }}=interface
set network.{{ name }}.proto={{ s(name) }}
set network.{{ name }}.metric={{ s(config.metric) }}
set network.{{ name }}.zone='unet'
set network.{{ name }}.domain={{ s(config.domain) }}
{%	for (let network in local_network): %}
add_list network.{{ name }}.local_network={{ s(network) }}
{%	endfor %}
set network.{{ name }}.key={{ s(config.key) }}
set network.{{ name }}.auth_key={{ s(config.auth_key) }}
{% endfor %}
