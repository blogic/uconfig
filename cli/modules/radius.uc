import * as uconfig from 'cli.uconfig';
import * as editor from 'cli.object-editor';
import { readfile, writefile } from 'fs';

let radius = json(readfile('/etc/uconfig/data/radius.json') || '{}');

model.radius = {};

const radius_user_editor = {
	change_cb: () => model.radius.changed = true,

	named_args: {
		password: {
			help: 'The password that this user needs to provide during authentication requests',
			required: true,
			args: {
				type: 'string',
			}
		},

		'vlan-id': {
			help: 'The VLAN that that the user gets assigned',
			args: {
				type: 'int',
				min: 1,
				max: 4095
			}
		},

		'max-rate-up': {
			help: 'The maximum upload rate that the user gets assigned in kbit',
			args: {
				type: 'int',
			}
		},

		'max-rate-down': {
			help: 'The maximum download rate that the user gets assigned in kbit',
			args: {
				type: 'int',
			}
		},
	},
};
const RadiusUser = model.add_node('RadiusUser', editor.new(radius_user_editor));

const radius_user_edit_create_destroy = {
	change_cb: () => model.radius.changed = true,

	types: {
		user: {
			node_name: 'RadiusUser',
			node: RadiusUser,
		},
	},
};

const radius_editor = {
	change_cb: () => model.radius.changed = true,

	named_args: {
		secret: {
			help: 'The shared secret between server and clients',
			default: 'secret',
			required: true,
			args: {
				type: 'string',
				min: 1,
			}
		},
	}
};

const Radius = {
	commit: {
		help: 'Commit and apply pending changes',
		call: function(ctx, argv) {
			if (!model.radius.changed)
				return ctx.error('NO_CHANGES', 'There are no pending changes\n');
			
			writefile('/etc/uconfig/data/radius.json', radius);
			model.radius.changed = false;

			return ctx.ok('Done');
		}
	},
};
editor.new(radius_editor, Radius);
editor.edit_create_destroy(radius_user_edit_create_destroy, Radius);
model.add_node('Radius', Radius);

function exit_radius_cb() {
	if (!model.radius.changed)
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
	radius: {
		help: 'Configure the local radius server',
		no_subcommands: true,
		select_node: 'Radius',
		select: function(ctx, argv) {
			ctx.add_hook('exit', exit_radius_cb);
			return ctx.set(null, { edit: radius, object_edit: radius });
		},
	}
};
model.add_node('Root', Root);
