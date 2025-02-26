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
			attribute: 'leds_active',
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
			attribute: 'login_required',
			args: {
				type: 'bool',
			}
		},
	}
};
let Unit = model.add_node('Unit', editor.new(unit_editor));

const Edit = {
	unit: {
		help: 'Configure unit settings',
		select_node: 'Unit',
		select: function(ctx, argv) {
			return ctx.set(null, {
				edit: uconfig.lookup([ 'unit' ]),
			});
		},
	}
};
model.add_node('Edit', Edit);
