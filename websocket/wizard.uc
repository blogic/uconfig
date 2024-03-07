import { readfile, writefile } from 'fs';

function load_config(file) {
	return json(readfile('/etc/uconfig/examples/' + file));
}

function router(data) {
	let config = load_config('webui-router.wizard');
	config.unit.hostname = 'OpenWrt';

	config.interfaces.lan.ssids.main.ssid = data.name;
	config.interfaces.lan.ssids.main.encryption.key = data.main_psk;

	config.interfaces.lan.ssids.mesh.disable = !data.mesh_wifi;
	config.interfaces.lan.ssids.mesh.ssid = data.name + '_Mesh';
	
	config.interfaces.guest.disable = !data.guest_wifi;
	config.interfaces.guest.ssids.guest.ssid = data.name + '_Guest';;
	config.interfaces.guest.ssids.guest.encryption.key = data.main_psk;

	writefile('/tmp/webui.cfg.json', config);
	system('uconfig_apply /tmp/webui.cfg.json');
}

export function generate(data) {
	switch(data.mode) {
	case 'ap':
		ap(data);
		break;
	case 'router':
		router(data);
		break;
	}
};
