# Setup bridge
add network device
set network.@device[-1].name={{ name }}
set network.@device[-1].type=bridge
set network.@device[-1].igmp_snooping='1'
set network.@device[-1].multicast_to_unicast='1'
