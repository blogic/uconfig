{%
	import { md5 } from 'digest';
	import * as radius from 'uconfig.radius';

	// Constants
	const ENTERPRISE_WPA_MODES = [ 'wpa', 'wpa2', 'wpa-mixed', 'wpa3', 'wpa3-mixed', 'wpa3-192' ];
	const PSK_MODES = [ 'psk', 'psk2', 'psk-mixed', 'sae', 'sae-mixed' ];
	const OWE_MODES = [ 'owe', 'owe-transition' ];
	const NONE_MODES = [ 'none' ];
	const WDS_MODES = [ 'wds-ap', 'wds-sta', 'wds-repeater' ];
	const SAE_MODES = [ 'sae', 'sae-mixed' ];
	const WPA3_MODES = [ 'sae', 'wpa3', 'wpa3-192' ];
	const WPA3_MIXED_MODES = [ 'sae-mixed', 'wpa3-mixed' ];
	const COMPATIBLE_6G_MODES = [ 'wpa3', 'wpa3-mixed', 'wpa3-192', 'sae', 'sae-mixed', 'owe' ];
	const ROAMING_INCOMPATIBLE_MODES = [ 'wpa', 'psk', 'none' ];
	const BASIC_BSS_MODES = [ 'ap', 'sta' ];
	const IEEE80211W_OPTIONS = [ 'disabled', 'optional', 'required' ];
	const CERTIFICATES = {
		ca_certificate: '/etc/uconfig/certificates/ca.pem',
		certificate: '/etc/uconfig/certificates/cert.pem',
		private_key: '/etc/uconfig/certificates/cert.key'
	};

	// Helper functions grouped by prefix

	// has_ functions
	function has_remote_radius() {
		return ssid.radius && ssid.radius.authentication &&
		       ssid.radius.authentication.host &&
		       ssid.radius.authentication.port &&
		       ssid.radius.authentication.secret;
	}

	// is_ functions
	function is_6g_band(phy) {
		return '6G' in phy.band;
	}

	function is_6g_compatible_encryption() {
		return ssid?.encryption.proto in COMPATIBLE_6G_MODES;
	}

	function is_enterprise_wpa() {
		return ssid.encryption.proto in ENTERPRISE_WPA_MODES;
	}

	function is_no_encryption() {
		return !ssid.encryption || ssid.encryption.proto in NONE_MODES;
	}

	function is_owe_encryption() {
		return ssid?.encryption?.proto in OWE_MODES;
	}

	function is_psk_encryption() {
		return ssid.encryption.proto in PSK_MODES;
	}

	// match_ functions
	function match_ieee80211w(phy) {
		if (is_6g_band(phy))
			return 2;

		if (is_no_encryption())
			return 0;

		if (ssid.encryption.proto in WPA3_MIXED_MODES)
			return 1;

		if (ssid.encryption.proto in WPA3_MODES)
			return 2;

		return index(IEEE80211W_OPTIONS, ssid.encryption.ieee80211w);
	}

	function match_sae_pwe(phy) {
		if (is_6g_band(phy))
			return 1;

		return '';
	}

	function match_wds() {
		return index(WDS_MODES, ssid.bss_mode) >= 0;
	}

	// normalize_ functions
	function normalize_bss_mode() {
		switch (ssid.bss_mode) {
			case 'wds-ap': return 'ap';
			case 'wds-sta': return 'sta';
			default: return ssid.bss_mode;
		}
	}

	function normalize_radius_config() {
		if (!ssid.encryption?.radius_server)
			return;

		ssid.radius = radius.lookup(ssid.encryption.radius_server, state.definitions);
	}

	function normalize_system_defaults() {
		if (ssid.purpose != 'system-defaults' || !board.wlan.defaults)
			return;

		let defaults = board.wlan.defaults.ssids?.all;

		if (!defaults)
			return;

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

	function normalize_template_config() {
		if (!ssid.template?.mode)
			return;

		delete ssid.encryption;

		switch (ssid.template.mode) {
		case 'open':
			ssid.encryption = {
				proto: 'none'
			};
			break;

		case 'encrypted':
			if (ssid.template.security == 'legacy') {
				ssid.encryption = {
					proto: 'psk2',
					key: ssid.template.key,
					ieee80211w: 'disabled'
				};
			} else {
				ssid.encryption = {
					proto: (ssid.template.security == 'compatibility') ? 'sae-mixed' : 'sae',
					key: ssid.template.key,
					ieee80211w: (ssid.template.security == 'compatibility') ? 'optional' : 'required'
				};
			}
			if (!exists(ssid, 'roaming'))
				ssid.roaming = true;
			break;

		case 'enterprise':
			ssid.encryption = {
				proto: (ssid.template.security == 'compatibility') ? 'wpa3-mixed' : 'wpa3',
				radius_server: ssid.template['radius-server'],
				ieee80211w: (ssid.template.security == 'compatibility') ? 'optional' : 'required'
			};
			break;

		case 'opportunistic':
			ssid.encryption = {
				proto: (ssid.template.security == 'compatibility') ? 'owe-transition' : 'owe',
				ieee80211w: 'required'
			};
			break;

		case 'batman-adv':
			ssid.wifi_radios = [ '5G' ];
			ssid.bss_mode = 'mesh';
			ssid.hidden = true;
			ssid.encryption = {
				proto: 'psk2',
				key: ssid.template.key,
				ieee80211w: 'required'
			};
			break;
		}
	}

	function normalize_roaming_config() {
		if (type(ssid.roaming) == 'bool') {
			if (ssid.roaming)
				ssid.roaming = {
					message_exchange: 'air',
					generate_psk: false,
				};
			else
				delete ssid.roaming;
		}

		if (ssid.roaming && ssid.encryption.proto in ROAMING_INCOMPATIBLE_MODES) {
			delete ssid.roaming;
			warn('Roaming requires wpa2 or later');
		}
	}

	function normalize_rate_limit() {
		if (type(ssid.rate_limit) == 'int') {
			ssid.rate_limit = {
				ingress_rate: ssid.rate_limit,
				egress_rate: ssid.rate_limit,
			};
		}
	}

	// supports_ functions
	function supports_bss_mode(supported_modes, mode) {
		return index(supported_modes, mode) >= 0;
	}

	// validate_ functions
	function validate_encryption_ap() {
		if (is_enterprise_wpa() && has_remote_radius())
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
		if (is_enterprise_wpa() && length(CERTIFICATES))
			return {
				proto: ssid.encryption.proto,
				client_tls: CERTIFICATES
			};
		warn('Cannot find any valid encryption settings');

		return false;
	}

	function validate_encryption(phy) {
		if (is_6g_band(phy) && !is_6g_compatible_encryption()) {
			warn('Invalid encryption settings for 6G band');
			return null;
		}

		if (is_no_encryption())
			return {
				proto: 'none'
			};

		if (is_owe_encryption())
			return {
				proto: 'owe'
			};

		if (is_psk_encryption() && ssid.encryption.key)
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

	// Utility functions
	function add_radius_attributes(section, attributes, attr_type) {
		if (!attributes || !length(attributes))
			return '';

		let output = [];
		for (let request in attributes)
			uci_list_string(output, `wireless.${section}.radius_${attr_type}_req_attr`,
				request.id + ':' + request.value);

		return uci_output(output);
	}

	function generate_sae_psk_file() {
		let path = `/var/run/hostapd-${name}-${count}.psk`;
		let file = fs.open(path, 'w');

		if (!file)
			die('Failed to open SAE PSK file: ' + path);

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

		return path;
	}

	function generate_wpa_psk_file() {
		let path = `/var/run/hostapd-${name}-${count}.psk`;
		let file = fs.open(path, 'w');

		if (!file)
			die('Failed to open WPA PSK file: ' + path);

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

		return path;
	}

	function setup_multi_psk() {
		if (!ssid.multi_psk)
			return;

		if (ssid.encryption.proto in SAE_MODES)
			ssid.sae_password_file = generate_sae_psk_file();
		else if (ssid.encryption.proto == 'psk2')
			ssid.wpa_psk_file = generate_wpa_psk_file();
	}

	// Configuration generation functions ordered by template call order

	function generate_basic_section(section, location, phys) {
		let output = [];

		uci_comment(output, '# generated by ssid.uc');
		uci_comment(output, '### generate basic wireless section');
		uci_named_section(output, `wireless.${section}`, 'wifi-iface');
		uci_set_string(output, `wireless.${section}.uconfig_path`, location);
		for (let phy in phys)
			uci_list_string(output, `wireless.${section}.device`, phy.section);

		return uci_output(output);
	}

	function generate_owe_transition(section) {
		if (!ssid?.encryption?.proto || ssid.encryption.proto != 'owe-transition')
			return '';

		let output = [];

		uci_comment(output, '### generate owe transition settings');
		uci_set_boolean(output, `wireless.${section}.owe_transition`, true);

		return uci_output(output);
	}

	function generate_mesh_config(section, bss_mode) {
		if (!supports_bss_mode(['mesh'], bss_mode))
			return '';

		let output = [];

		uci_comment(output, '### generate mesh configuration');
		uci_set_string(output, `wireless.${section}.mode`, bss_mode);
		uci_set_string(output, `wireless.${section}.mesh_id`, ssid.ssid);
		uci_set_boolean(output, `wireless.${section}.mesh_fwding`, false);
		uci_set_string(output, `wireless.${section}.network`, 'batman_mesh');
		uci_set_number(output, `wireless.${section}.mcast_rate`, 24000);

		return uci_output(output);
	}

	function generate_basic_bss_config(section, bss_mode, network) {
		if (!supports_bss_mode(BASIC_BSS_MODES, bss_mode))
			return '';

		let output = [];

		uci_comment(output, '### generate basic bss configuration');
		uci_set_string(output, `wireless.${section}.network`, network);
		uci_set_string(output, `wireless.${section}.ssid`, ssid.ssid);
		uci_set_string(output, `wireless.${section}.mode`, bss_mode);
		uci_set_string(output, `wireless.${section}.bssid`, ssid.bssid);
		uci_set_boolean(output, `wireless.${section}.wds`, match_wds());
		uci_set_boolean(output, `wireless.${section}.wpa_disable_eapol_key_retries`, ssid.wpa_disable_eapol_key_retries);
		uci_set_string(output, `wireless.${section}.vendor_elements`, ssid.vendor_elements);
		uci_set_boolean(output, `wireless.${section}.auth_cache`, ssid.encryption?.key_caching);

		return uci_output(output);
	}

	function generate_crypto_base(section, crypto, phys) {
		let output = [];

		let ieee80211w = 0;
		let sae_pwe = '';
		for (let phy in phys) {
			let w = match_ieee80211w(phy);
			if (w > ieee80211w)
				ieee80211w = w;
			if (is_6g_band(phy))
				sae_pwe = 1;
		}

		uci_comment(output, '### generate crypto base settings');
		uci_set_number(output, `wireless.${section}.ieee80211w`, ieee80211w);
		uci_set_string(output, `wireless.${section}.sae_pwe`, sae_pwe);
		uci_set_string(output, `wireless.${section}.encryption`, crypto.proto);
		uci_set_string(output, `wireless.${section}.key`, crypto.key);

		return uci_output(output);
	}


	function generate_radius_auth_config(section, crypto) {
		if (!crypto.auth)
			return '';

		let output = [];

		uci_comment(output, '### generate radius authentication configuration');
		uci_set_string(output, `wireless.${section}.auth_server`, crypto.auth.host);
		uci_set_number(output, `wireless.${section}.auth_port`, crypto.auth.port);
		uci_set_string(output, `wireless.${section}.auth_secret`, crypto.auth.secret);
		if (crypto.auth.request_attribute && length(crypto.auth.request_attribute))
			push(output, add_radius_attributes(section, crypto.auth.request_attribute, 'auth'));

		return uci_output(output);
	}

	function generate_radius_acct_config(section, crypto) {
		if (!crypto.acct)
			return '';

		let output = [];

		uci_comment(output, '### generate radius accounting configuration');
		uci_set_string(output, `wireless.${section}.acct_server`, crypto.acct.host);
		uci_set_number(output, `wireless.${section}.acct_port`, crypto.acct.port);
		uci_set_string(output, `wireless.${section}.acct_secret`, crypto.acct.secret);
		uci_set_number(output, `wireless.${section}.acct_interval`, crypto.acct.interval);
		if (crypto.acct.request_attribute && length(crypto.acct.request_attribute))
			push(output, add_radius_attributes(section, crypto.acct.request_attribute, 'acct'));

		return uci_output(output);
	}

	function generate_dynamic_auth_config(section, crypto) {
		if (!crypto.dyn_auth)
			return '';

		let output = [];

		uci_comment(output, '### generate dynamic authorization configuration');
		uci_set_string(output, `wireless.${section}.dae_client`, crypto.dyn_auth.host);
		uci_set_number(output, `wireless.${section}.dae_port`, crypto.dyn_auth.port);
		uci_set_string(output, `wireless.${section}.dae_secret`, crypto.dyn_auth.secret);

		return uci_output(output);
	}

	function generate_radius_general_config(section, crypto) {
		if (!crypto.radius)
			return '';

		let output = [];

		uci_comment(output, '### generate general radius configuration');
		uci_set_boolean(output, `wireless.${section}.request_cui`, crypto.radius.chargeable_user_id);
		uci_set_string(output, `wireless.${section}.nasid`, crypto.radius.nas_identifier);
		uci_set_boolean(output, `wireless.${section}.dynamic_vlan`, true);

		return uci_output(output);
	}

	function generate_client_tls_config(section, crypto, certificates) {
		if (!crypto.client_tls)
			return '';

		let output = [];

		uci_comment(output, '### generate client tls configuration');
		uci_set_string(output, `wireless.${section}.eap_type`, 'tls');
		uci_set_string(output, `wireless.${section}.ca_cert`, certificates.ca_certificate);
		uci_set_string(output, `wireless.${section}.client_cert`, certificates.certificate);
		uci_set_string(output, `wireless.${section}.priv_key`, certificates.private_key);
		uci_set_string(output, `wireless.${section}.priv_key_pwd`, certificates.private_key_password);
		uci_set_string(output, `wireless.${section}.identity`, 'OpenWrt');

		return uci_output(output);
	}

	function generate_ap_basic_config(section, bss_mode, interface) {
		if (!supports_bss_mode(['ap'], bss_mode))
			return '';

		let output = [];

		uci_comment(output, '### generate ap basic configuration');
		uci_set_boolean(output, `wireless.${section}.hidden`, ssid.hidden_ssid);
		uci_set_boolean(output, `wireless.${section}.isolate`, ssid.isolate_clients);
		uci_set_boolean(output, `wireless.${section}.bridge_isolate`, interface.isolate_hosts);
		uci_set_boolean(output, `wireless.${section}.multicast_to_unicast`, ssid.unicast_conversion);

		return uci_output(output);
	}

	function generate_rate_limit_config(section) {
		if (!ssid.rate_limit)
			return '';

		let output = [];

		uci_comment(output, '### generate rate limit configuration');
		uci_set_boolean(output, `wireless.${section}.ratelimit`, true);

		return uci_output(output);
	}

	function generate_access_control_config(section) {
		if (!ssid.access_control_list?.mode)
			return '';

		let output = [];

		uci_comment(output, '### generate access control configuration');
		uci_set_string(output, `wireless.${section}.macfilter`, ssid.access_control_list.mode);
		for (let mac in ssid.access_control_list.mac_address)
			uci_list_string(output, `wireless.${section}.maclist`, mac);

		return uci_output(output);
	}

	function generate_roaming_config(section) {
		if (!ssid.roaming)
			return '';

		let output = [];

		uci_comment(output, '### generate roaming configuration');
		uci_set_boolean(output, `wireless.${section}.ieee80211r`, true);
		uci_set_boolean(output, `wireless.${section}.ft_over_ds`, ssid.roaming.message_exchange == 'ds');
		uci_set_boolean(output, `wireless.${section}.ft_psk_generate_local`, ssid.roaming.generate_psk);
		uci_set_string(output, `wireless.${section}.mobility_domain`, ssid.roaming.domain_identifier);

		return uci_output(output);
	}

	function generate_psk_files_config(section) {
		let output = [];

		uci_comment(output, '### generate psk files configuration');
		uci_set_string(output, `wireless.${section}.wpa_psk_file`, ssid.wpa_psk_file);
		uci_set_string(output, `wireless.${section}.sae_password_file`, ssid.sae_password_file);

		return uci_output(output);
	}

	function generate_vlan_config(section) {
		let output = [];

		uci_comment(output, '### generate vlan configuration');
		uci_section(output, 'wireless wifi-vlan');
		uci_set_string(output, 'wireless.@wifi-vlan[-1].iface', section);
		uci_set_string(output, 'wireless.@wifi-vlan[-1].name', 'v#');
		uci_set_string(output, 'wireless.@wifi-vlan[-1].vid', '*');

		return uci_output(output);
	}

	function generate_rate_limit_rules(section) {
		if (!ssid.rate_limit || (!ssid.rate_limit.ingress_rate && !ssid.rate_limit.egress_rate))
			return '';

		let output = [];

		uci_comment(output, '### generate rate limit rules');
		uci_named_section(output, `ratelimit.${md5(ssid.ssid)}`, 'rate');
		uci_set_number(output, 'ratelimit.@rate[-1].ingress', `${ssid.rate_limit.ingress_rate}mbit`);
		uci_set_number(output, 'ratelimit.@rate[-1].egress', `${ssid.rate_limit.egress_rate}mbit`);
	
		services.set_enabled('ratelimit', 'restart');

		return uci_output(output);
	}

	let phys = [];

	for (let band in ssid.wifi_radios)
		for (let phy in wiphy.lookup(band))
			if (phy.section)
				push(phys, phy);

	if (!length(phys)) {
		warn('Cannot find any suitable radio phy for SSID "%s" settings', ssid.ssid);

		return;
	}

	// Main normalisation pipeline
	normalize_radius_config();
	normalize_system_defaults();
	normalize_template_config();
	normalize_roaming_config();
	normalize_rate_limit();
	setup_multi_psk();

	let bss_mode = normalize_bss_mode();
%}

{%
	let valid_phys = [];
	let crypto;
	for (let phy in phys) {
		let c = validate_encryption(phy);
		if (c) {
			push(valid_phys, phy);
			crypto ??= c;
		}
	}

	if (length(valid_phys)):
		let section = name + '_' + count;
%}
{{ generate_basic_section(section, location, valid_phys) }}
{{ generate_owe_transition(section) }}
{{ generate_mesh_config(section, bss_mode) }}
{{ generate_basic_bss_config(section, bss_mode, network) }}

## Crypto settings
{{ generate_crypto_base(section, crypto, valid_phys) }}
{{ generate_radius_auth_config(section, crypto) }}
{{ generate_radius_acct_config(section, crypto) }}
{{ generate_dynamic_auth_config(section, crypto) }}
{{ generate_radius_general_config(section, crypto) }}
{{ generate_client_tls_config(section, crypto, CERTIFICATES) }}

## AP specific settings
{{ generate_ap_basic_config(section, bss_mode, interface) }}
{{ generate_rate_limit_config(section) }}
{{ generate_access_control_config(section) }}
{{ generate_roaming_config(section) }}
{{ generate_psk_files_config(section) }}
{{ generate_vlan_config(section) }}
{{ generate_rate_limit_rules(section) }}
{% endif %}

