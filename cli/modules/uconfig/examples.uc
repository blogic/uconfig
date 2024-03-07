import * as uconfig from 'cli.uconfig';
import { basename, glob } from 'fs';

function examples_get() {
	let examples = glob('/etc/uconfig/examples/*.json');

	return map(examples, (v) => split(basename(v), '.')[0]);
}

const examples_apply_args = [
	{
		name: 'name',
		help: 'Example name',
		type: 'enum',
		value: examples_get,
	}
];

const ucExamples = {
	list: {
		help: 'List all example configurations',
		call: function(ctx, argv) {
			let examples = examples_get();

			return ctx.list('ucExamples', examples);
		}
	},

	apply: {
		help: 'Apply an example configurations',
		args: examples_apply_args,
		call: function(ctx, argv) {
			let name = shift(argv);
			
			if (!name)
				return ctx.error('MISSING_OPTION', 'Missing example name');

			return uconfig.apply(ctx, `/etc/uconfig/examples/${name}.json`);
		}
	},
};
model.add_node('ucExamples', ucExamples);

const uConfig = {
	examples: {
		help: 'Try out some example configurations',
		select_node: 'ucExamples',
	},
};
uconfig.add_node('uConfig', uConfig);
