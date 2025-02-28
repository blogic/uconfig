import * as uconfig from 'cli.uconfig';

const ucServices = {
	list: {
		help: 'List all available services',
		call: function(ctx, argv) {
			return ctx.list('ucServices', sort(model.uconfig.services));
		}
	},
};
uconfig.add_node('ucServices', ucServices);

const ucEdit = {
	services: {
		help: 'Manage services running on the device',
		select_node: 'ucServices'
	},
};
uconfig.add_node('ucEdit', ucEdit);

model.uconfig.services = [];

model.add_modules('uconfig/services/*.uc');
