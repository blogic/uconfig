#!/usr/bin/ucode

'use strict';

import * as fs from 'fs';
import * as wiphy from 'uconfig.wiphy';
import { uci } from 'uconfig.uci';

let capa = {
	uuid: time(),
};

let board = fs.readfile('/etc/board.json');
board = json(board);
let initial = fs.readfile('/etc/uconfig/examples/initial.json');
initial = json(initial);

initial.uuid = time();

capa.compatible = board.model.id;
capa.model = board.model.name;

capa.network = {};
capa.serial = uci.get('system', '@system[-1]', 'serial');
let macs = {};
for (let k, v in board.network) {
	if (!board.network.wan && k == 'lan')
		k = 'wan';
	if (v.ports)
		capa.network[k] = v.ports;
	if (v.device)
		capa.network[k] = [v.device];
	if (v.ifname)
		capa.network[k] = split(replace(v.ifname, /^ */, ''), ' ');
	if (v.macaddr)
		macs[k] = v.macaddr;
}

if (length(macs))
	capa.macaddr = macs;

if (board.system?.label_macaddr)
	capa.label_macaddr = board.system?.label_macaddr;

if (length(wiphy.phys)) {
	capa.wifi = [ ];
	for (let k, v in wiphy.phys) {
		push(capa.wifi, { phy: k, ...v });
		for (let band, data in v.bands) {
			band = uc(band);
			initial.radios[band] = {
        	                'channel-mode': 'HE',
                	        'channel-width': (band == '2G') ? 20 : 80,
				channel: data.default_channel,
	                };
		}
	}
}

fs.writefile('/etc/uconfig/capabilities.json', capa);

let path = '/etc/uconfig/uconfig.cfg.' + initial.uuid;
fs.writefile(path, initial);
fs.symlink(path, '/etc/uconfig/uconfig.active');
