import * as uconfig from 'cli.uconfig';
import * as editor from "cli.object-editor";

const ntp_editor = {
	change_cb: uconfig.changed,
	
	named_args: {
		'servers': {
			help: "string value",
			multiple: true,
			args: {
				type: "string",
			}
		},
	}
};

const NTP = editor.new(ntp_editor);

const Services = {
	ntp: {
		help: 'Edit the list of NTP servers',
		select_node: 'NTP',
		select: function(ctx, argv) {
			return ctx.set(null, { edit : uconfig.lookup([ 'services', 'ntp' ])});
		},
	},
};

push(model.uconfig.services, 'ntp');

return {
	nodes: { Services, NTP },
};
