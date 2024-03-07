# uconfig - OpenWrt JSON based configuration

An intend based configuration wrapper using JSON files. The data model is based on jsonschema.

    root@openwrt:~# uconfig_apply /etc/uconfig/examples/dumb-ap.json
 
 There are several examples located in "render/example/*.json"
 
## What is currently supported

* networking (IPv4/6, NAT, firewall, VLANs)
* wifi (AP, STA, WDS, MESH, ...)
* dynamic VLAN (radius)
* local EAP server
* wired ieee8021x authentication
* client rate limiting
* multi psk (mac, rate limit, vlan)
* services (ssh, ntp, log, mdns, lldp)

## What does intent base mean ?

The config files describe the intended behavior of the device. The render code will then work out what UCI needs to look like. Here are some examples
* enabling a service such as SSH on an interface will automatically configure the firewall
* automatic creation of multiple routing tables in case of multiple VLAN uplinks
* automatic fallback for radio settings

## What does uconfig-event do ?

The service registers to various ubus objects. It will take care of setting up dynamic vlans, rate limits, listen to carrier events, ...
In addition you can call the following to get timestamped system events in JSON format

    root@openwrt:~# ubus call event log

## What are the requirements ?

* for all features to work a full version of wpad needs to be installed
* fingerprinting and dhcp snooping require a BPF toolchain
