{%-
	if (!services.is_present("adguardhome"))
		return;

	let interfaces = services.lookup_interfaces("adguardhome");
	let enable = length(interfaces);
	services.set_enabled("adguardhome", !!enable ? 'restart' : false);
	if (!enable)
		return;
	let servers = adguardhome.servers || [ '8.8.8.8' ];
	if (!fs.stat('/etc/adguardhome.yaml'))
		system(`ucode -T /usr/share/ucode/uconfig/adguardhome.yaml ${adguardhome?.webui_port || 3000} ${adguardhome.password} ${join(' ', servers) } > /etc/adguardhome.yaml`); 
%}

# Configure Adguardhome
set dhcp.@dnsmasq[0].port="54"

{%	for (let interface in interfaces): %}
# Configure adguardhome firewall
add firewall rule
set firewall.@rule[-1].name='Allow-adguard-{{ interface.name }}'
set firewall.@rule[-1].src='{{ interface.name }}'
set firewall.@rule[-1].dest_port='{{ adguardhome?.webui_port || 3000 }}'
set firewall.@rule[-1].proto='tcp'
set firewall.@rule[-1].target='ACCEPT'
{%		if (adguardhome?.dns_intercept): %}
add firewall redirect
set firewall.@rule[-1].name='Intercept-adguard-{{ interface.name }}'
set firewall.@redirect[-1].src='{{ interface.name }}'
set firewall.@redirect[-1].proto='tcp udp'
set firewall.@redirect[-1].src_dport='53'
set firewall.@redirect[-1].target='DNAT'
set firewall.@redirect[-1].dest='{{ interface.name }}'
set firewall.@redirect[-1].dest_port='53'
{%		endif %}
{%	endfor %}
