'use strict';

// Storage the device can share: what is plugged in, and whether it is offered
// over SMB.
//
// Restored from an earlier web UI, where it lived as one `storage` method
// taking an action string. Split into two methods to match the handler table
// the rest of this server uses, and the share call takes the state it wants
// rather than flipping whatever is there: a client that retries a lost request
// should not turn a share back off.

import * as ubus from 'ubus';
import { readfile } from 'fs';
import { cursor } from 'uci';
import {
	ERROR_METHOD_NOT_FOUND,
	ERROR_INVALID_PARAMS,
	ERROR_INTERNAL,
	response_success,
	response_error
} from 'uconfig.webui.uwsd.jsonrpc';

let send_response;

const MOUNT_ROOT = '/mnt';

// sysfs reports every `size` in 512-byte units whatever the device's logical
// block size is, so this is a constant and not a lookup. Multiplying by
// queue/logical_block_size, which is what the original did, overstates a 4Kn
// disk eightfold.
const SECTOR_BYTES = 512;

// Filesystems that are the firmware rather than storage someone plugged in.
const INTERNAL_TYPES = { squashfs: true, ubifs: true, jffs2: true };
const INTERNAL_MOUNTS = { '/rom': true, '/overlay': true };

function base_device_name(name) {
	return replace(name, /p?[0-9]+$/, '');
}

function sysfs_read(path) {
	let raw = readfile(path);
	return raw ? trim(raw) : null;
}

// A partition's own size, falling back to the whole disk for a device that has
// no partition table. Reading only the parent, which the original did, reports
// a 1 TB disk for a 100 GB partition on it.
function device_size(name) {
	let base = base_device_name(name);
	let sectors = (base != name) ? sysfs_read(`/sys/block/${base}/${name}/size`) : null;

	sectors ??= sysfs_read(`/sys/block/${base}/size`);

	return sectors ? (+sectors * SECTOR_BYTES) : null;
}

function device_model(name) {
	let base = base_device_name(name);
	let vendor = sysfs_read(`/sys/block/${base}/device/vendor`);
	let model = sysfs_read(`/sys/block/${base}/device/model`);

	if (vendor && model)
		return `${vendor} ${model}`;

	return model ?? vendor;
}

function device_removable(name) {
	return sysfs_read(`/sys/block/${base_device_name(name)}/removable`) == '1';
}

function mount_find(name, uuid, label) {
	let uci = cursor();
	let found;

	uci.foreach('fstab', 'mount', (section) => {
		if (section.device != name && (!uuid || section.uuid != uuid) && (!label || section.label != label))
			return;
		found = section;
		return false;
	});

	return found;
}

function share_find(uci, name) {
	let found;

	uci.foreach('samba4', 'sambashare', (section) => {
		if (section.name != name)
			return;
		found = section;
		return false;
	});

	return found;
}

// Guest-readable and writable by anyone who can reach the network, which is
// what the original wrote and why file sharing is offered on the local network
// only. There are no accounts to check against.
function share_add(uci, name, path) {
	if (share_find(uci, name))
		return true;

	let section = uci.add('samba4', 'sambashare');

	if (!section)
		return false;

	uci.set('samba4', section, 'name', name);
	uci.set('samba4', section, 'path', path);
	uci.set('samba4', section, 'guest_ok', 'yes');
	uci.set('samba4', section, 'guest_only', 'yes');
	uci.set('samba4', section, 'read_only', 'no');
	uci.set('samba4', section, 'create_mask', '0666');
	uci.set('samba4', section, 'dir_mask', '0777');
	uci.set('samba4', section, 'force_root', '1');
	uci.set('samba4', section, 'inherit_owner', 'yes');

	return true;
}

function share_remove(uci, name) {
	let existing = share_find(uci, name);

	if (existing)
		uci.delete('samba4', existing['.name']);

	return true;
}

function device_describe(dev) {
	let name = dev.device;
	let label = dev.label;
	let share = label ?? name;
	let mount = mount_find(name, dev.uuid, label);

	return {
		name,
		device: `/dev/${name}`,
		type: dev.type ?? null,
		version: dev.version ?? null,
		uuid: dev.uuid ?? null,
		label: label ?? null,
		// Bytes rather than a formatted string: the client already formats
		// these, and a number chosen here would arrive untranslated.
		size_bytes: device_size(name),
		model: device_model(name),
		removable: device_removable(name),
		mounted: dev.mount != null,
		mount_point: dev.mount ?? null,
		share_name: share,
		target: mount?.target ?? `${MOUNT_ROOT}/${share}`,
		shared: mount ? (mount.enabled == '1') : false
	};
}

function device_internal(dev) {
	return INTERNAL_TYPES[dev.type] || INTERNAL_MOUNTS[dev.mount];
}

function handle_storage(connection, id, params) {
	let info = ubus.call('block', 'info');

	if (!info)
		return send_response(connection, response_error(id, ERROR_METHOD_NOT_FOUND, 'Storage management is not installed on this device'));

	let devices = [];

	for (let dev in info.devices ?? []) {
		if (device_internal(dev))
			continue;
		push(devices, device_describe(dev));
	}

	send_response(connection, response_success(id, { ready: info.ready ?? false, devices }));
}

// One call writes both the fstab entry and the share, because a share pointing
// at a path nothing mounts is a share that never works.
function handle_storage_share(connection, id, params) {
	if (type(params) != 'object' || type(params.device) != 'string' || type(params.shared) != 'bool')
		return send_response(connection, response_error(id, ERROR_INVALID_PARAMS, 'Invalid params'));

	let info = ubus.call('block', 'info', { device: params.device });

	if (!info)
		return send_response(connection, response_error(id, ERROR_INTERNAL, 'Device not found'));

	let dev = info.devices?.[0] ?? info;
	let label = dev.label;

	// The fstab entry keys on uuid or label so it survives the stick moving to
	// another port; a device name does not.
	if (!dev.uuid && !label)
		return send_response(connection, response_error(id, ERROR_INTERNAL, 'Device has no UUID or label to key a mount on'));

	let share = label ?? params.device;
	let uci = cursor();

	uci.load('fstab');
	uci.load('samba4');

	let existing = mount_find(params.device, dev.uuid, label);
	let section = existing ? existing['.name'] : uci.add('fstab', 'mount');

	// block-mount writes an entry of its own for anything it sees, so one
	// usually exists already with a target chosen by the system. Keep it:
	// moving a mount point because the label reads better is not this call's
	// business, and anything already pointing at the old path would break.
	let target = existing?.target ?? `${MOUNT_ROOT}/${share}`;

	if (!section)
		return send_response(connection, response_error(id, ERROR_INTERNAL, 'Failed to create the mount entry'));

	if (dev.uuid)
		uci.set('fstab', section, 'uuid', dev.uuid);
	else
		uci.set('fstab', section, 'label', label);

	uci.set('fstab', section, 'target', target);
	uci.set('fstab', section, 'enabled', params.shared ? '1' : '0');

	if (params.shared)
		share_add(uci, share, target);
	else
		share_remove(uci, share);

	if (!uci.commit('fstab') || !uci.commit('samba4'))
		return send_response(connection, response_error(id, ERROR_INTERNAL, 'Failed to write the configuration'));

	// Mounting is what makes the share usable now rather than after a reboot.
	ubus.call('block', params.shared ? 'mount' : 'umount', {});
	system('/etc/init.d/samba4 restart');

	send_response(connection, response_success(id, { success: true }));
}

export function register(handlers, ctx) {
	send_response = ctx.send_response;

	handlers['storage']       = { handler: handle_storage,       auth_required: true };
	handlers['storage-share'] = { handler: handle_storage_share, auth_required: true };
};
