import * as uconfig from 'cli.uconfig';
import { readfile, writefile } from 'fs';

let unet = json(readfile('/etc/uconfig/data/unetd.json') || '{}');

function unet_store(name, data) {
	unet[name] = data;
	writefile('/etc/uconfig/data/unetd.json', unet);
	system('/sbin/uconfig_apply -n /etc/uconfig/uconfig.active');
}

model.add_hook("unet_create", unet_store);
model.add_hook("unet_update", unet_store);

function unet_delete(name, data) {
	delete unet[name];
	writefile('/etc/uconfig/data/unetd.json', unet);
	system('/sbin/uconfig_apply -n /etc/uconfig/uconfig.active');
}
model.add_hook("unet_delete", unet_delete);
