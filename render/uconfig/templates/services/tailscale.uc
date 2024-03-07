{%
	let interfaces = services.lookup_interfaces("tailscale");
	let enable = length(interfaces);
	services.set_enabled("tailscale", !!enable);
	if (!enable)
		return;
%}

# Configure Tailscale
set network.tailscale=interface
set network.tailscale.ifname=tailscale0
set network.tailscale.proto=none

# Configure Tailscale Firewall
add firewall zone
set firewall.@zone[-1].name='tailscale'
set firewall.@zone[-1].input='ACCEPT'
set firewall.@zone[-1].output='ACCEPT'
set firewall.@zone[-1].forward='ACCEPT'
add_list firewall.@zone[-1].network='tailscale'

{% for (let name, iface in interfaces): %}
add firewall forwarding
set firewall.@forwarding[-1].name='Allow-tailscale-{{ iface.name }}'
set firewall.@forwarding[-1].src='tailscale'
set firewall.@forwarding[-1].dest={{ s(iface.name) }}
{% 	if (iface.role == 'downstream'): %}
add firewall forwarding
set firewall.@forwarding[-1].name='Allow-tailscale-{{ iface.name }}_2'
set firewall.@forwarding[-1].src={{ s(iface.name) }}
set firewall.@forwarding[-1].dest='tailscale'
{% 	endif
   endfor %}
