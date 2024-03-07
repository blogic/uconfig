import * as uconfig from 'cli.uconfig';
import * as editor from "cli.object-editor";
import { readfile, writefile } from 'fs';

let config = json(readfile('/etc/uconfig/data/local.json') || '{}');
let zoneinfo = json(readfile('/usr/share/ucode/uconfig/zoneinfo.json') || '{}');
model.local = { };

const local_editor = {
	change_cb: () => model.local.changed = true,

	named_args: {
		hostname: {
			help: 'The devices hostname',
			args: {
				type: 'string',
			}
		},

		timezone: {
			help: 'The devices timezone',
			prefix_separator: '/',
			args: {
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
		'ssh-keys': {
			help: "List of valid SSH keys",
			attribute: 'authorized_keys',
			multiple: true,
			args: {
				type: "string",
			}
		},
	}
};

const Local = {
	commit: {
		help: 'Store and apply pending changes',
		call: function(ctx, argv) {
			model.local.changed = false;
			writefile('/etc/uconfig/data/local.json', config);
			return ctx.ok('Done');
		},
	}
};
editor.new(local_editor, Local);
model.add_node('Local', Local);

function exit_local_cb() {
	if (!model.local.changed)
		return true;

	warn(`Pending changes will be lost. Exit anyway ? (y|n) `);
	while (1) {
		key = lc(model.cb.poll_key());
		if (key == null || key == 'y')
			return true;
		if (key == 'n')
			return false;
	}
	warn(key + '\n');
}

const Root = {
	local: {
		help: 'Configure static local settings',
		no_subcommands: true,
		select_node: 'Local',
		select: function(ctx, argv) {
			ctx.add_hook('exit', exit_local_cb);
			return ctx.set(null, {
				edit: config,
			});
		},
	}
};
model.add_node('Root', Root);
