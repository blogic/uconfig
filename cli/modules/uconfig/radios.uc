import * as uconfig from 'cli.uconfig';
import * as editor from "cli.object-editor";

const radio_editor = {
	change_cb: uconfig.changed,

	named_args: {
		'channel-mode': {
			help: 'Define the ideal channel mode that the radio shall use.',
			default: function(ctx)	{
				return ctx.data.default_mode;
			},
			required: true,
			args: {
				type: 'enum',
				value: function(ctx) {
					return ctx.data.channel_mode;
				}
			}
		},

		'channel-width': {
			help: 'The channel width that the radio shall use. ',
			default: function(ctx) {
				return ctx.data.default_width;
			},
			required: true,
			args: {
				type: 'enum',
				value: function(ctx) {
					return ctx.data.channel_width;
				}
			}
		},

		'channel': {
			help: 'Specifies the wireless channel to use.',
			default: 80,
			required: true,
			args: {
				type: 'int',
			}
		},

		'allow-dfs': {
			help: 'This property defines whether a radio may use DFS channels.',
			default: true,
			available: function(ctx) {
				return ctx.data.allow_dfs;
			},
			args: {
				type: 'bool',
			}
		},

		'maximum-clients': {
			help: 'Set the maximum number of clients that may connect to this radio. This value is accumulative for all attached VAP interfaces.',
			args: {
				type: 'int',
			}
		},

		'he-multiple-bssid': {
			help: 'Enabling this option will make the PHY broadcast its BSSs using the multiple BSSID beacon IE.',
			available: function(ctx) {
				return ('HE' in ctx.data.channel_mode);
			},
			args: {
				type: 'bool',
			}
			
		},
	}
};

let Bands = { };

function create_band(band, values) {
	let allow_dfs = (band == '5G');
	let channel_mode = [];
	let default_mode = [];
	let channel_width = [];
	let default_width;
	let width = 20;

	for (let mode in [ 'ht', 'vht', 'he', 'eht' ])
		if (values[mode]) {
			default_mode = uc(mode);
			push(channel_mode, default_mode);
		}
	
	while (width <= (values.max_width || 20)) {
		if (width < 160)
			default_width = width;
		push(channel_width, width);
		width *= 2;
	}

	return {
		band,
		channel_mode,
		default_mode,
		channel_width,
		default_width,
		allow_dfs,
	};
}

model.uconfig.bands = [];

for (let phy in uconfig.capabilities.wifi) {
	for (let k, v in phy.bands) {
		Bands[k] = create_band(k, v);
		push(model.uconfig.bands, k);
		uconfig.add_node(k, editor.new(radio_editor));
	}
}

model.uconfig.bands = sort(uniq(model.uconfig.bands));

const ucEdit = {
	radios: {
		help: 'Manage the wireless radios on the device',

		args: [
			{
				name: 'band',
				type: 'enum',
				value: () => keys(Bands),
				required: true,
			}
		],

		select_node: '2G',

		select: function(ctx, argv) {
			let band = argv[0];
			if (!band) {
				warn(`Error: No radio provided\n`);
	                        return;
			}
			ctx.node = model.node[band];

			return ctx.set(`radios ${band}`, {
				...Bands[band],
				edit : uconfig.lookup([ 'radios', band ]),
			});
		},
	},
};
uconfig.add_node('ucEdit', ucEdit);
