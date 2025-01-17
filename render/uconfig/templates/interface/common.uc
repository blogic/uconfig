{# check how many address families this interface has#}
{% let afnames = ethernet.calculate_names(interface) %}
{# interfaces that have IPv4 and IPv6 require a dummy interface with proto:none #}
{% if (length(afnames) >= 2): %}
# Configure an interface
set network.{{ name }}=interface
set network.{{ name }}.uconfig_name={{ s(interface.name) }}
set network.{{ name }}.uconfig_path={{ s(location) }}
set network.{{ name }}.device={{ netdev }}
set network.{{ name }}.metric={{ interface.metric }}
set network.{{ name }}.proto=none
{% endif %}
{# create the per address family interface section #}
{% for (let afidx, afname in afnames): %}
# Configure an interface
set network.{{ afname }}=interface
set network.{{ afname }}.uconfig_name={{ s(interface.name) }}
set network.{{ afname }}.uconfig_path={{ s(location) }}
set network.{{ afname }}.ifname={{ netdev }}
set network.{{ afname }}.metric={{ interface.metric }}
set network.{{ afname }}.mtu={{ interface.mtu }}
set network.{{ afname }}.type={{ interface.type }}
{%	if (ipv4_mode == 'static' || ipv6_mode == 'static'): %}
set network.{{ afname }}.proto=static
{%	elif ((length(afnames) == 1 || afidx == 0) && ipv4_mode == 'dynamic'): %}
set network.{{ afname }}.proto=dhcp
{%	elif ((length(afnames) == 1 || afidx == 1) && ipv6_mode == 'dynamic'): %}
set network.{{ afname }}.proto=dhcpv6
{%	else %}
set network.{{ afname }}.proto=none
{%	endif %}
{# downstream interfaces need to be told what routing table to use as their lookup #}
{%	if (interface.role == "downstream" && ethernet.has_vlan(interface)): %}
# Configure a VLAN's routing table
add network rule
set network.@rule[-1].in={{ afname }}
set network.@rule[-1].lookup={{ routing_table.get(interface.vlan.id) }}
{%  endif %}
{# render IPv4 specific settings #}
{%  if (ipv4_mode != 'none' && (length(afnames) == 1 || afidx == 0)): %}
{%   include('ipv4.uc', { name: afname }) %}
{%  endif %}
{# render IPv6 specific settings #}
{%  if (ipv6_mode != 'none' && (length(afnames) == 1 || afidx == 1)): %}
{%   include('ipv6.uc', { name: afname }) %}
{%  endif %}
{% endfor %}
