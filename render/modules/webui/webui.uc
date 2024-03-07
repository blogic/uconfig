{%-
	if (!services.is_present('uconfig-server'))
		return;

	let interfaces = services.lookup_interfaces('webui');
	let enable = length(interfaces);
	services.set_enabled('uconfig-server', !!enable);
	if (!enable)
		return;
%}

# Configure WebUi
{%	for (let interface in interfaces): %}
add firewall rule
set firewall.@rule[-1].name='Allow-webui-{{ interface.name }}'
set firewall.@rule[-1].src='{{ interface.name }}'
set firewall.@rule[-1].dest_port='80'
set firewall.@rule[-1].proto='tcp'
set firewall.@rule[-1].target='ACCEPT'

{%	endfor %}
