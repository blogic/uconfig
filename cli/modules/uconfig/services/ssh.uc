import * as uconfig from 'cli.uconfig';
import * as editor from "cli.object-editor";

const ssh_editor = {
	change_cb: uconfig.changed,

	named_args: {
		port: {
			help: 'SSH port',
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
			help: "string value",
			multiple: true,
			args: {
				type: "string",
			}
		},
	}
};
model.add_node('SSH', editor.new(ssh_editor));

const Services = {
	ssh: {
		help: 'Edit the SSH servers settings',
		select_node: 'SSH',
		select: function(ctx, argv) {
			return ctx.set(null, { edit : uconfig.lookup([ 'services', 'ssh' ])});
		},
	},
};
model.add_node('Services', Services);

push(model.uconfig.services, 'ssh');
