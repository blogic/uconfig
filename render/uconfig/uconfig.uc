'use strict';

let error = 0;
let logs = [];

import * as fs from 'fs';
import * as reader from 'ureader.schema';
import * as renderer from 'uconfig.renderer';
import * as files from 'uconfig.files';
import * as services from 'uconfig.services';

function stdout(txt) {
	fs.stdout.write('\-\-\- ' + txt + '\n');
}

function log_output(verbose, logs, batch) {
	if (length(logs))
		stdout('Log messages:\n' + join('\n', logs) + '\n');
	if (verbose && batch)
		stdout('UCI batch output:\n' + batch);
}

function generate(file, verbose, test, no_apply) {
	/* flush previous state */
	files.init();
	services.init();
	logs = [];

	/* read the input file */
	let cfgjson = files.read(file);

	/* remove some old files */
	for (let cmd in [ 'rm -rf /tmp/uconfig',
			  'mkdir /tmp/uconfig',
			  'rm -f /tmp/dnsmasq.conf',
			  'touch /tmp/dnsmasq.conf' ])
		system(cmd);

	/* validate the configuration */
	stdout('validating config');
	let state = reader.validate(cfgjson, logs);

	/* die if the reader failed to validate the config */
	if (!state) {
		log_output(verbose, logs);
		return -1;
	}

	/* generate the UCI batch sequence */
	stdout('generating config');
	let batch = renderer.generate(state, logs, { files, services });

	if (state.strict && length(logs)) {
		push(logs, 'Rejecting config due to strict-mode validation');
		state = null;
		verbose = true;
	}

	/* print some debug output */
	log_output(verbose, logs, batch);

	files.write('/tmp/uconfig.logs', join('\n', logs));

	if (!state)
		return -1;

	/* write the UCI batch file */
	files.write('/tmp/uconfig.uci', batch);

	if (test)
		return 0;

	/* preapre the sanitized shadow config */
	for (let cmd in [ 'rm -rf /tmp/uconfig-shadow',
			  'cp -r /etc/uconfig/shadow /tmp/uconfig-shadow',
			  'cp -r /etc/config/system /tmp/uconfig-shadow/' ])
		system(cmd);

	/* import the UCI batch file */
	stdout('writing config');
	files.popen('/sbin/uci -q -c /tmp/uconfig-shadow -C "" batch' + (!verbose ? ' > /dev/null' : '') , batch);

	/* write all dynamically generated files */
	files.generate(logs);

	/* disable all none used services */
	stdout('stopping services');
	services.stop(no_apply);

	/* copy generated shadow config to /etc/config/ and reload the configuration */
	for (let cmd in [ 'uci -q -c /tmp/uconfig-shadow -C "" commit',
			  'cp /tmp/uconfig-shadow/* /var/run/uci/',
			  'rm -rf /tmp/uconfig-shadow' ])
		system(cmd);

	if (!no_apply) {
		stdout('applying config');
		system('reload_config');
	}

	/* enable all used services */
	stdout('starting services');
	services.start(no_apply);

	return 0;
}

return {
	generate
};
