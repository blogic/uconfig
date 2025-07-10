{%
	let phys = [];

	for (let band in ssid.wifi_radios)
		for (let phy in wiphy.lookup(band))
			if (phy.section)
				push(phys, phy);

	if (!length(phys)) {
		warn('Cannot find any suitable radio phy for SSID "%s" settings', ssid.ssid);

		return;
	}

	if (ssid.purpose == 'system-defaults' && board.wlan.defaults) {
		let defaults = board.wlan.defaults.ssids?.all;
		if (defaults) {
			warn('overriding ssid with system defaults\n');
			ssid = {
				ssid: defaults.ssid,
				wifi_radios: [ '2G', '5G' ],
				bss_mode: 'ap',
				roaming: true,
				encryption: {
					proto: defaults.encryption,
					key: defaults.key,
					ieee80211w: 'optional'
				}
			};
		}
	}
	
	if (ssid.template != 'manual') {
		let new = {
			encryption: {},
		};

		for (let key in [ 'ssid', 'bss_mode', 'wifi_radios', 'hidden_ssid', 'roaming', 'rate_limit', 'isolate_clients',
				  'bssid', 'unicast_conversion', 'multi_psk', 'access_control_list' ])
			if (ssid[key])
				new[key] = ssid[key];

		switch (ssid.template) {
		case 'open':
			new.encryption.proto = 'none';
			break;

		case 'encrypted':
			new.encryption.proto = (ssid.security == 'compatibility') ? 'sae-mixed' : 'sae';
			new.encryption.key = ssid.encryption?.key;
			new.ieee80211w = (ssid.security == 'compatibility') ? 'optional' : 'required';
			new.roaming = true;
			break;

		case 'enterprise':
			new.encryption.proto = (ssid.security == 'compatibility') ? 'wpa3-mixed' : 'wpa3';
			new.ieee80211w = (ssid.security == 'compatibility') ? 'optional' : 'required';
			break;
		
		case 'batman-adv':
			new.wifi_radios = [ '5G' ];
			new.bss_mode = 'mesh';
			new.hidden = true;
			new.encryption.proto = 'psk2';
			new.encryption.key = ssid.encryption?.key;
			new.encryption.ieee80211w = 'required';
			break;
		}

		ssid = new;
	}

	if (state.configurations?.radius_servers)
		ssid.radius = state.configurations?.radius_servers[ssid.encryption?.radius_server];

	if (type(ssid.roaming) == 'bool')
		ssid.roaming = {
			message_exchange: 'air',
			generate_psk: false,
		};

	if (type(ssid.rate_limit) == 'int')
		ssid.rate_limit = {
			ingress_rate: ssid.rate_limit,
			egress_rate: ssid.rate_limit,
		};

	if (ssid.roaming && ssid.encryption.proto in [ 'wpa', 'psk', 'none' ]) {
		delete ssid.roaming;
		warn('Roaming requires wpa2 or later');
	}

	let certificates = {
		ca_certificate: '/etc/uconfig/certificates/ca.pem',
		certificate: '/etc/uconfig/certificates/cert.pem',
		private_key: '/etc/uconfig/certificates/cert.key'
	};

	function validate_encryption_ap() {
		if (ssid.encryption.proto in [ 'wpa', 'wpa2', 'wpa-mixed', 'wpa3', 'wpa3-mixed', 'wpa3-192' ] &&
		    ssid.radius && ssid.radius.local &&
		    length(certificates))
			return {
				proto: ssid.encryption.proto,
				eap_local: ssid.radius.local,
				eap_user: '/tmp/uconfig/' + replace(location, '/', '_') + '.eap_user'
			};


		if (ssid.encryption.proto in [ 'wpa', 'wpa2', 'wpa-mixed', 'wpa3', 'wpa3-mixed', 'wpa3-192' ] &&
		    ssid.radius && ssid.radius.authentication &&
		    ssid.radius.authentication.host &&
		    ssid.radius.authentication.port &&
		    ssid.radius.authentication.secret)
			return {
				proto: ssid.encryption.proto,
				auth: ssid.radius.authentication,
				acct: ssid.radius.accounting,
				dyn_auth: ssid.radius?.dynamic_authorization,
				radius: ssid.radius
			};
		warn('Cannot find any valid encryption settings');
		return false;
	}

	function validate_encryption_sta() {
		if (ssid.encryption.proto in [ 'wpa', 'wpa2', 'wpa-mixed', 'wpa3', 'wpa3-mixed', 'wpa3-192' ] &&
		    length(certificates))
			return {
				proto: ssid.encryption.proto,
				client_tls: certificates
			};
		warn('Cannot find any valid encryption settings');
		return false;
	}

	function validate_encryption(phy) {
		if ('6G' in phy.band && !(ssid?.encryption.proto in [ 'wpa3', 'wpa3-mixed', 'wpa3-192', 'sae', 'sae-mixed', 'owe' ])) {
			warn('Invalid encryption settings for 6G band');
			return null;
		}

		if (!ssid.encryption || ssid.encryption.proto in [ 'none' ]) {
			if (ssid.radius?.authentication?.mac_filter &&
			    ssid.radius.authentication?.host &&
			    ssid.radius.authentication?.port &&
			    ssid.radius.authentication?.secret)
				return {
					proto: 'none',
					auth: ssid.radius.authentication,
					acct: ssid.radius.accounting,
					dyn_auth: ssid.radius?.dynamic_authorization,
					radius: ssid.radius
				};
			return {
				proto: 'none'
			};
		}

		if (ssid?.encryption?.proto in [ 'owe', 'owe-transition' ])
			return {
				proto: 'owe'
			};

		if (ssid.encryption.proto in [ 'psk', 'psk2', 'psk-mixed', 'sae', 'sae-mixed' ] &&
		    ssid.encryption.key)
			return {
				proto: ssid.encryption.proto,
				key: ssid.encryption.key
		};

		switch(ssid.bss_mode) {
		case 'ap':
		case 'wds-ap':
			return validate_encryption_ap();

		case 'sta':
		case 'wds-sta':
			return validate_encryption_sta();

		}
		warn('Cannot find any valid encryption settings');
	}

	function match_ieee80211w(phy) {
		if ('6G' in phy.band)
			return 2;

		if (!ssid.encryption || ssid.encryption.proto in [ 'none' ])
			return 0;

		if (ssid.encryption.proto in [ 'sae-mixed', 'wpa3-mixed' ])
			return 1;

		if (ssid.encryption.proto in [ 'sae', 'wpa3', 'wpa3-192' ])
			return 2;

		return index([ 'disabled', 'optional', 'required' ], ssid.encryption.ieee80211w);
	}

	function match_wds() {
		return index([ 'wds-ap', 'wds-sta', 'wds-repeater' ], ssid.bss_mode) >= 0;
	}

	function match_sae_pwe(phy) {
		if ('6G' in phy.band)
			return 1;
		return '';
	}

	if (ssid.multi_psk && ssid.encryption.proto in [ 'sae', 'sae-mixed' ]) {
		let path = `/var/run/hostapd-${name}-${count}.psk`;
		let file = fs.open(path, 'w');
		for (let name, psk in ssid.multi_psk) {
			if (!psk.key || !psk.mac)
				continue;
			let line = psk.key;
			if (psk.vlan)
				line += `|vlanid=${psk.vlan}`;
			for (let mac in psk.mac)
				file.write(line + `|mac=${mac}\n`);
		}
		file.close();
		ssid.sae_password_file = path; 
	}

	if (ssid.multi_psk && ssid.encryption.proto in [ 'psk2' ]) {
		let path = `/var/run/hostapd-${name}-${count}.psk`;
		let file = fs.open(path, 'w');
		for (let name, psk in ssid.multi_psk) {
			if (!psk.key)
				continue;
			let line = '';
			if (psk.vlan)
				line += `vlanid=${psk.vlan} `;
			psk.mac ??= [ '00:00:00:00:00:00' ];
			for (let mac in psk.mac)
				file.write(`${line}${mac} ${psk.key}\n`);
		}
		file.close();
		ssid.wpa_psk_file = path; 
	}

	let bss_mode = ssid.bss_mode;
	if (ssid.bss_mode == 'wds-ap')
		bss_mode =  'ap';
	if (ssid.bss_mode == 'wds-sta')
		bss_mode =  'sta';
%}

# Wireless configuration
{% for (let n, phy in phys): %}
{%
     let section = name + '_' + n + '_' + count;
     let crypto = validate_encryption(phy);
     if (!crypto) continue;
%}
set wireless.{{ section }}=wifi-iface
set wireless.{{ section }}.uconfig_path={{ s(location) }}
set wireless.{{ section }}.device={{ phy.section }}

{%   if (ssid?.encryption?.proto == 'owe-transition'): %}
set wireless.{{ section }}.owe_transition=1
{%   endif %}

{%   if (bss_mode == 'mesh'): %}
set wireless.{{ section }}.mode={{ bss_mode }}
set wireless.{{ section }}.mesh_id={{ s(ssid.ssid) }}
set wireless.{{ section }}.mesh_fwding=0
set wireless.{{ section }}.network=batman_mesh
set wireless.{{ section }}.mcast_rate=24000
{%   endif %}

{%   if (index([ 'ap', 'sta' ], bss_mode) >= 0): %}
set wireless.{{ section }}.network={{ network }}
set wireless.{{ section }}.ssid={{ s(ssid.ssid) }}
set wireless.{{ section }}.mode={{ s(bss_mode) }}
set wireless.{{ section }}.bssid={{ ssid.bssid }}
set wireless.{{ section }}.wds='{{ b(match_wds()) }}'
set wireless.{{ section }}.wpa_disable_eapol_key_retries='{{ b(ssid.wpa_disable_eapol_key_retries) }}'
set wireless.{{ section }}.vendor_elements='{{ ssid.vendor_elements }}'
set wireless.{{ section }}.auth_cache='{{ b(ssid.encryption?.key_caching) }}'
{%   endif %}

# Crypto settings
set wireless.{{ section }}.ieee80211w={{ match_ieee80211w(phy) }}
set wireless.{{ section }}.sae_pwe={{ match_sae_pwe(phy) }}
set wireless.{{ section }}.encryption={{ crypto.proto }}
set wireless.{{ section }}.key={{ s(crypto.key) }}

{%   if (crypto.eap_local): %}
set wireless.{{ section }}.eap_server=1
set wireless.{{ section }}.ca_cert={{ s(certificates.ca_certificate) }}
set wireless.{{ section }}.server_cert={{ s(certificates.certificate) }}
set wireless.{{ section }}.private_key={{ s(certificates.private_key) }}
set wireless.{{ section }}.private_key_passwd={{ s(certificates.private_key_password) }}
set wireless.{{ section }}.server_id={{ s(crypto.eap_local.server_identity) }}
set wireless.{{ section }}.eap_user_file={{ s(crypto.eap_user) }}
{%     files.add_named(crypto.eap_user, render('../eap_users.uc', { users: crypto.eap_local.users })) %}
{%   endif %}

{%   if (crypto.auth): %}
set wireless.{{ section }}.auth_server={{ crypto.auth.host }}
set wireless.{{ section }}.auth_port={{ crypto.auth.port }}
set wireless.{{ section }}.auth_secret={{ crypto.auth.secret }}
{%     for (let request in crypto.auth.request_attribute): %}
add_list wireless.{{ section }}.radius_auth_req_attr={{ s(request.id + ':' + request.value) }}
{%     endfor %}
{%   endif %}

{%   if (crypto.acct): %}
set wireless.{{ section }}.acct_server={{ crypto.acct.host }}
set wireless.{{ section }}.acct_port={{ crypto.acct.port }}
set wireless.{{ section }}.acct_secret={{ crypto.acct.secret }}
set wireless.{{ section }}.acct_interval={{ crypto.acct.interval }}
{%     for (let request in crypto.acct.request_attribute): %}
add_list wireless.{{ section }}.radius_acct_req_attr={{ s(request.id + ':' + request.value) }}
{%     endfor %}
{%   endif %}

{%   if (crypto.dyn_auth): %}
set wireless.{{ section }}.dae_client={{ crypto.dyn_auth.host }}
set wireless.{{ section }}.dae_port={{ crypto.dyn_auth.port }}
set wireless.{{ section }}.dae_secret={{ crypto.dyn_auth.secret }}
{%   endif %}

{%   if (crypto.radius): %}
set wireless.{{ section }}.request_cui={{ b(crypto.radius.chargeable_user_id) }}
set wireless.{{ section }}.nasid={{ s(crypto.radius.nas_identifier) }}
set wireless.{{ section }}.dynamic_vlan=1
{%     if (crypto.radius?.authentication?.mac_filter): %}
set wireless.{{ section }}.macfilter=radius
{%     endif %}
{%   endif %}

{%   if (crypto.client_tls): %}
set wireless.{{ section }}.eap_type='tls'
set wireless.{{ section }}.ca_cert={{ s(certificates.ca_certificate) }}
set wireless.{{ section }}.client_cert={{ s(certificates.certificate)}}
set wireless.{{ section }}.priv_key={{ s(certificates.private_key) }}
set wireless.{{ section }}.priv_key_pwd={{ s(certificates.private_key_password) }}
set wireless.{{ section }}.identity='OpenWrt'
{%   endif %}

# AP specific setings
{%   if (bss_mode == 'ap'): %}
set wireless.{{ section }}.hidden={{ b(ssid.hidden_ssid) }}
set wireless.{{ section }}.isolate={{ b(ssid.isolate_clients) }}
set wireless.{{ section }}.bridge_isolate={{ b(interface.isolate_hosts) }}
set wireless.{{ section }}.multicast_to_unicast={{ b(ssid.unicast_conversion) }}

{%     if (ssid.rate_limit): %}
set wireless.{{ section }}.ratelimit=1
{%     endif %}

{%     if (ssid.access_control_list?.mode): %}
set wireless.{{ section }}.macfilter={{ s(ssid.access_control_list.mode) }}
{%       for (let mac in ssid.access_control_list.mac_address): %}
add_list wireless.{{ section }}.maclist={{ s(mac) }}
{%       endfor %}
{%     endif %}

{%     if (ssid.roaming): %}
set wireless.{{ section }}.ieee80211r=1
set wireless.{{ section }}.ft_over_ds={{ b(ssid.roaming.message_exchange == 'ds') }}
set wireless.{{ section }}.ft_psk_generate_local={{ b(ssid.roaming.generate_psk) }}
set wireless.{{ section }}.mobility_domain={{ ssid.roaming.domain_identifier }}
{%     endif %}

set wireless.{{ section }}.wpa_psk_file={{ s(ssid.wpa_psk_file) }}
set wireless.{{ section }}.sae_password_file={{ s(ssid.sae_password_file) }}

add wireless wifi-vlan
set wireless.@wifi-vlan[-1].iface={{ section }}
set wireless.@wifi-vlan[-1].name='v#'
set wireless.@wifi-vlan[-1].vid='*'

{%     if (ssid.rate_limit && (ssid.rate_limit.ingress_rate || ssid.rate_limit.egress_rate)): %}
add ratelimit rate
set ratelimit.@rate[-1].ssid={{ s(ssid.ssid) }}
set ratelimit.@rate[-1].ingress={{ ssid.rate_limit.ingress_rate }}
set ratelimit.@rate[-1].egress={{ ssid.rate_limit.egress_rate }}
{%     endif %}

{%   else %}

{%   endif %}
{% endfor %}
