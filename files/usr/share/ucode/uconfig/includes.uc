'use strict';

import * as fs from 'fs';

let include_sources = {};

const INCLUDE_DIRS = {
	ucoord: '/etc/ucoord/configs',
	local: '/etc/uconfig',
};

function source_parts(source) {
	let parts = split(source, ':');
	if (length(parts) != 2)
		return null;

	let dir = INCLUDE_DIRS[parts[0]];

	// The name becomes a path, so keep it to something that cannot climb out of
	// the directory the prefix chose.
	if (!dir || !match(parts[1], /^[A-Za-z0-9._-]+$/))
		return null;

	return { dir, path: `${dir}/${parts[1]}.json` };
}

function source_path_resolve(source) {
	return source_parts(source)?.path;
}

function source_load(name, source, logs) {
	let path = source_path_resolve(source);
	if (!path) {
		if (logs)
			push(logs, `Include source '${name}' has invalid source format: ${source}`);
		return null;
	}

	let content = fs.readfile(path);
	if (!content) {
		if (logs)
			push(logs, `Include source '${name}' not found: ${path}`);
		return null;
	}

	let data;
	try {
		data = json(content);
	} catch (e) {
		data = null;
	}

	if (!data) {
		if (logs)
			push(logs, `Include source '${name}' invalid JSON: ${path}`);
		return null;
	}

	if (!data.uuid) {
		if (logs)
			push(logs, `Include source '${name}' missing required uuid property`);
		return null;
	}

	return data;
}

function dir_create(path) {
	let current = '';

	for (let part in split(path, '/')) {
		if (part == '')
			continue;
		current += `/${part}`;
		if (!fs.access(current, 'r'))
			fs.mkdir(current, 0755);
	}
}

// A client sends fragment contents while the document only points at a file, so
// storing one resolves the same way the loader reads it back.
export function source_store(source, fragment) {
	let parts = source_parts(source);
	if (!parts)
		return false;

	// source_load rejects a fragment without one, and ucoord compares them to
	// decide which copy of a venue-wide overlay is the newer.
	fragment.uuid ??= time();

	dir_create(parts.dir);

	return fs.writefile(parts.path, sprintf('%.J', fragment)) != null;
};

export function source_fetch(name, source) {
	return source_load(name, source, null);
};

function path_resolve(data, path) {
	let parts = split(path, '.');
	let current = data;

	for (let part in parts) {
		if (type(current) != 'object')
			return null;
		current = current[part];
	}

	return current;
}

function deep_merge(target, source) {
	if (type(source) != 'object')
		return source;
	if (type(target) != 'object')
		target = {};

	for (let key, value in source) {
		if (type(value) == 'object' && type(target[key]) == 'object')
			target[key] = deep_merge(target[key], value);
		else
			target[key] = value;
	}

	return target;
}

function object_process(obj) {
	if (type(obj) != 'object')
		return obj;

	let includes = obj.include;
	if (type(includes) == 'array') {
		delete obj.include;

		for (let include_path in includes) {
			let parts = split(include_path, '.', 2);
			let source_name = parts[0];
			let data_path = parts[1];

			let source_data = include_sources[source_name];
			if (!source_data)
				continue;

			let snippet = data_path ? path_resolve(source_data, data_path) : source_data;
			if (snippet)
				obj = deep_merge(obj, snippet);
		}
	}

	for (let key, value in obj) {
		if (type(value) == 'object')
			obj[key] = object_process(value);
	}

	return obj;
}

export function process(config, logs) {
	include_sources = {};
	let includes_map = config.includes;
	let failed = false;

	if (type(includes_map) == 'object') {
		for (let name, source in includes_map) {
			let data = source_load(name, source, logs);
			if (data)
				include_sources[name] = data;
			else
				failed = true;
		}
		delete config.includes;
	}

	if (failed)
		return null;

	return object_process(config);
};
