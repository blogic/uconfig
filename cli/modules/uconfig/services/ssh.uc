import * as uconfig from 'cli.uconfig';
import * as editor from "cli.object-editor";

const ssh_editor = {
	change_cb: uconfig.changed,

	named_args: {
		port: {
			help: 'Network port',
			default: 22,
			required: true,
			args: {
				type: 'int',
				min: 1,
				max: 65535,
			}
		},

		'password-authentication': {
			help: 'Allow logins using a password',
			default: true,
			args: {
				type: 'bool',
			}
		},

		'authorized-keys': {
			help: "List of public keys that may connect",
			multiple: true,
			args: {
				type: "string",
			}
		},
	}
};
uconfig.add_node('ucSSH', editor.new(ssh_editor));

const ucServices = {
	ssh: {
		help: 'Edit the SSH servers settings',
		select_node: 'ucSSH',
		select: function(ctx, argv) {
			return ctx.set(null, { edit : uconfig.lookup([ 'services', 'ssh' ])});
		},
	},
};
uconfig.add_node('ucServices', ucServices);

push(model.uconfig.services, 'ssh');
