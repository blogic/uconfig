const Services = {
	list: {
		help: 'List all available services',
		call: function(ctx, argv) {
			return ctx.list('Services', sort(model.uconfig.services));
		}
	},
};
model.add_node('Services', Services);

const Edit = {
	services: {
		help: 'Manage services running on the device',
		select_node: 'Services'
	},
};
model.add_node('Edit', Edit);

model.uconfig.services = [];

model.add_modules('uconfig/services/*.uc');
