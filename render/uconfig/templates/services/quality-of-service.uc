
# Configure QOSIFY
add qosify defaults
add_list qosify.@defaults[-1].defaults='/etc/qosify/*.conf'
set qosify.@defaults[-1].dscp_prio='video'
set qosify.@defaults[-1].dscp_icmp='+besteffort'
set qosify.@defaults[-1].dscp_default_udp='besteffort'
set qosify.@defaults[-1].prio_max_avg_pkt_len='500'

set qosify.besteffort=class
set qosify.besteffort.ingress='CS0'
set qosify.besteffort.egress='CS0'

set qosify.bulk=class
set qosify.bulk.ingress='LE'
set qosify.bulk.egress='LE'

set qosify.video=class
set qosify.video.ingress='AF41'
set qosify.video.egress='AF41'

set qosify.voice=class
set qosify.voice.ingress='CS6'
set qosify.voice.egress='CS6'
set qosify.voice.bulk_trigger_pps='100'
set qosify.voice.bulk_trigger_timeout='5'
set qosify.voice.dscp_bulk='CS0'
{%
	let enable = false;
	for (let name, iface in state.interfaces):
		if (iface.role != 'upstream')
			continue;
		if (!iface.quality_of_service?.bandwidth_up || !iface.quality_of_service?.bandwidth_down)
			continue;
		enable = true;
%}

set qosify.{{ name }}=interface
set qosify.{{ name }}.name='{{ name }}'
set qosify.{{ name }}.bandwidth_up='{{ iface.quality_of_service.bandwidth_up }}mbit'
set qosify.{{ name }}.bandwidth_down='{{ iface.quality_of_service.bandwidth_down }}mbit'
set qosify.{{ name }}.overhead_type='none'
set qosify.{{ name }}.ingress='1'
set qosify.{{ name }}.egress='1'
set qosify.{{ name }}.mode='diffserv4'
set qosify.{{ name }}.nat='1'
set qosify.{{ name }}.host_isolate='1'
set qosify.{{ name }}.autorate_ingress='0'
set qosify.{{ name }}.ingress_options=''
set qosify.{{ name }}.egress_options=''
set qosify.{{ name }}.options=''
{% endfor
services.set_enabled('qosify', !!enable);
%}
