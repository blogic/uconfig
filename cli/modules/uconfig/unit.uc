import * as uconfig from 'cli.uconfig';
import * as editor from "cli.object-editor";
import { readfile } from 'fs';

let zoneinfo = json(readfile('/usr/share/ucode/uconfig/zoneinfo.json') || '{}');

const unit_editor = {
	change_cb: uconfig.changed,

	named_args: {
		hostname: {
			help: 'The devices hostname',
			args: {
				type: 'string',
			}
		},

		timezone: {
			help: 'The devices timezone',
			args: {
				prefix_separator: '/',
				type: 'enum',
				value: function(ctx) {
					return keys(zoneinfo);
				}
			}
		},

		'leds-active': {
			help: 'Allows disabling all LEDs on the device',
			args: {
				type: 'bool',
			}
		},

		'root-password-hash': {
			help: 'The password hash that gets written to /etc/shadow/',
			attribute: 'password',
			args: {
				type: 'string',
			}
		},

		'tty-login-required': {
			help: 'Logins on the serial console require a password',
			args: {
				type: 'bool',
			}
		},
	}
};
let ucUnit = uconfig.add_node('ucUnit', editor.new(unit_editor));

const ucEdit = {
	unit: {
		help: 'Configure unit settings',
		select_node: 'ucUnit',
		select: function(ctx, argv) {
			return ctx.set(null, {
				edit: uconfig.lookup([ 'unit' ]),
			});
		},
	}
};
uconfig.add_node('ucEdit', ucEdit);
