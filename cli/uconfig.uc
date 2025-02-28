import { readfile, readlink, unlink, writefile } from 'fs';
import * as libubus from 'ubus';

export let ubus = libubus.connect();

export let capabilities = readfile('/etc/uconfig/capabilities.json');
if (capabilities)
	capabilities = json(capabilities);

export function service(cmd) {
	return system([ '/etc/init.d/uconfig', cmd ]);
};

function load_config() {
	delete model.uconfig.current_cfg;

	if (model.uconfig.status.uuid) {
		let txt = readfile(`/etc/uconfig/uconfig.cfg.${model.uconfig.status.uuid}`);
		if (txt)
			model.uconfig.current_cfg = json(txt);
	}

	if (!model.uconfig.current_cfg)
		model.uconfig.status = { active: false };
}

export function update_status() {
	let active = !service('enabled');
	let link = readlink('/etc/uconfig/uconfig.active');
	let uuid = link ? +(split(link, '.')[2]) : 0;

	model.uconfig.status = { active, uuid, };

	load_config();
};

export function apply(ctx, path) {
	if (system(`/sbin/uconfig_apply ${path}`))
		return ctx.error('APPLY_FAILED', 'Failed to apply config');
	update_status();
		return ctx.ok('Applied');
};

export function changed() {
	model.uconfig.changed = true;
	model.uconfig.dry_run = false;
};

export function dry_run(ctx) {
	let path = '/tmp/uconfig.dry-run';
	writefile(path, model.uconfig.current_cfg);

	let ret = system(`/sbin/uconfig_apply -t ${path}`);
	unlink(path);

	if (ret)
		return ctx.error('TEST_FAILED', 'Dry-run failed');

	model.uconfig.dry_run = false;

	return ctx.ok('Passed');
};

export function commit(ctx) {
	let path = '/tmp/uconfig.pending';
	writefile(path, model.uconfig.current_cfg);

	if (!model.uconfig.dry_run)
		if (system(`/sbin/uconfig_apply -t ${path}`))
			return ctx.error('TEST_FAILED', 'Dry-run failed');

	let ret = system(`/sbin/uconfig_apply ${path}`);
	unlink(path);
	
	if (ret)
		return ctx.error('APPLY_FAILED', 'Failed to apply config');
	
	model.uconfig.changed = false;
	model.uconfig.dry_run = false;

	update_status();

	return ctx.ok('Applied');
};

export function lookup(path) {
	let cfg = model.uconfig.current_cfg;

	for (let key in path) {
		cfg[key] ??= {};
		cfg = cfg[key];
	}

	return cfg;
};

let commit_call = {
	help: 'Commit and apply pending changes',
	call: function(ctx, argv) {
		if (!model.uconfig.changed)
			return ctx.error('NO_CHANGES', 'There are no pending changes\n');
	
		uconfig.commit(ctx);

		return ctx.ok('Done');
	}
};

export function add_node(name, obj) {
	obj.commit = commit_call;
	model.add_node(name, obj);
};
