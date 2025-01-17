# Basic configuration
set network.loopback=interface
set network.loopback.ifname='lo'
set network.loopback.proto='static'
set network.loopback.ipaddr='127.0.0.1'
set network.loopback.netmask='255.0.0.0'

{% for (let k, v in capabilities.macaddr): -%}
# Setup mac for {{ k }}
add network device
set network.@device[-1].name={{ s(capabilities.network[k][0]) }}
set network.@device[-1].macaddr={{ s(v) }}
{% endfor -%}
