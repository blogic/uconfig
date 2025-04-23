import * as uconfig from 'cli.uconfig';
import * as editor from 'cli.object-editor';
import * as state from 'uconfig.state';
import { basename, glob } from 'fs';

if (!uconfig.capabilities)
	return;

model.uconfig ??= {};
uconfig.update_status();

const uConfig = {
	disable: {
		help: 'Disable uConfig based UCI generation',
		call: function(ctx, argv) {
			let status = model.uconfig.status;

			if (!status.active)
				return ctx.error('SERVICE_NOT_RUNNING', 'Service not running');

			uconfig.service('disable');
			uconfig.service('stop');

			uconfig.update_status();

			return ctx.ok('Disabling');
		},
	},

	'dry-run': {
		help: 'Commit and apply pending changes',
		call: function(ctx, argv) {
			return uconfig.dry_run(ctx);
		}
	},	

	edit: {
		help: 'Edit the active configuration',
		select_node: 'ucEdit',
		select: function(ctx, argv) {
			if (!model.uconfig.current_cfg) {
				printf('FIXME: no config applied\n');
				return null;
			}

			return ctx.set(null, {
				object_edit: uconfig.lookup(),
			});
		},
	},

	enable: {
		help: 'Enable uConfig based UCI generation',
		call: function(ctx, argv) {
			let status = model.uconfig.status;

			if (status.active)
				return ctx.error('SERVICE_ALREADY_RUNNING', 'Service already running');
			else if (!status.uuid)
				return ctx.error('CONFIGURATION_NOT_AVAILABLE', 'Configuration not available');

			uconfig.service('enable');
			uconfig.service('start');

			uconfig.update_status();

			return ctx.ok('Enabling');
		},
	},

	list: {
		help: 'List all known configurations',
		call: function(ctx, argv) {
			let configs = glob('/etc/uconfig/uconfig.cfg.*');
			configs = map(configs, (v) => split(basename(v), '.')[2]);
			configs = map(configs, (v) => v + (model.uconfig.status.uuid == v ? ' - active' : ''));
			
			return ctx.list('Configs', configs);
		}
	},

	show: {
		help: 'Print the raw active config',
		call: function(ctx) {
			if (!model.uconfig.current_cfg)
				return ctx.error('CONFIGURATION_NOT_AVAILABLE', 'Configuration not available');

			return ctx.table('Config', model.uconfig.current_cfg);
		},
	},

	state: {
		help: 'Get the current state of the device',
		call: function(ctx, argv) {
			return ctx.table('State;', state.get());
		},
	},

	status: {
		help: 'Show current configuration status',
		call: function(ctx, argv) {
			let status = model.uconfig.status;

			let data = { Active: status.active };
			if (status.active && status.uuid) {
				data.UUID = status.uuid;
				data.Created = gmtime(status.uuid);
				data.status = status;
			}

			return ctx.table('Status', data);
		}
	},
};

if (global.uconfig_webui) {
	uConfig.reset = {
		call: function(ctx) {
			model.uconfig.changed = false;	
			uconfig.update_status();

			return ctx.ok('Done');
		}
	};

	uConfig.push = {
		call: function(ctx) {
			uconfig.push();
			return ctx.ok('Done');
		}
	};

	uConfig.pop = {
		call: function(ctx) {
			uconfig.pop();
			return ctx.ok('Done');
		}
	};

};

model.add_node('uConfig', uConfig);

function exit_uconfig_cb() {
	if (!model.uconfig.changed)
		return true;

	let key = model.poll_key([ 'y', 'n' ], `Pending changes will be lost. Exit anyway ? (y|n) `);
	if (!key)
		key = 'y';

	warn(key + '\n');
	return key == 'y';
}

const Root = {
	uconfig: {
		help: 'uConfig based configuration',
		no_subcommands: !global.uconfig_webui,
		select_node: 'uConfig',
		select: function(ctx, argv) {
			if (!global.uconfig_webui)
				ctx.add_hook('exit', exit_uconfig_cb);
			return ctx.set();
		},
	}
};
uconfig.add_node('Root', Root);

model.add_modules('uconfig/*.uc');
