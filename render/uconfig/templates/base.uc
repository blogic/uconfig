# Basic configuration
set network.loopback=interface
set network.loopback.ifname='lo'
set network.loopback.proto='static'
set network.loopback.ipaddr='127.0.0.1'
set network.loopback.netmask='255.0.0.0'

# Setup upstream bridge
set network.wan_bridge=device
set network.@device[-1].name=br-wan
set network.@device[-1].type=bridge
set network.@device[-1].igmp_snooping='1'
set network.@device[-1].multicast_to_unicast='1'

# Setup downstream bridge
set network.lan_bridge=device
set network.@device[-1].name=br-lan
set network.@device[-1].type=bridge
set network.@device[-1].igmp_snooping='1'
set network.@device[-1].multicast_to_unicast='1'

# Setup "un-managed" interface on upstream bridge
set network.wan_none=interface
set network.wan_none.ifname=br-wan
set network.wan_none.proto=none

{% for (let k, v in capabilities.macaddr): -%}
# Setup mac for {{ k }}
add network device
set network.@device[-1].name={{ s(capabilities.network[k][0]) }}
set network.@device[-1].macaddr={{ s(v) }}
{% endfor -%}
