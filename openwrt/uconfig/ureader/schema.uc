// Automatically ureader from ./schema-generated/schema.json - do not edit!
"use strict";

function matchUcCidr4(value) {
	let m = match(value, /^(auto|[0-9.]+)\/([0-9]+)$/);
	return m ? ((m[1] == "auto" || length(iptoarr(m[1])) == 4) && +m[2] <= 32) : false;
}

global.matchUcCidr4 = matchUcCidr4;

function matchUcCidr6(value) {
	let m = match(value, /^(auto|[0-9a-fA-F:.]+)\/([0-9]+)$/);
	return m ? ((m[1] == "auto" || length(iptoarr(m[1])) == 16) && +m[2] <= 128) : false;
}

global.matchUcCidr6 = matchUcCidr6;

function matchUcCidr(value) {
	let m = match(value, /^(auto|[0-9a-fA-F:.]+)\/([0-9]+)$/);
	if (!m) return false;
	let l = (m[1] == "auto") ? 16 : length(iptoarr(m[1]));
	return (l > 0 && +m[2] <= (l * 8));
}

global.matchUcCidr = matchUcCidr;

function matchUcMac(value) {
	return match(value, /^[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]$/i);
}

global.matchUcMac = matchUcMac;

function matchUcHost(value) {
	if (length(iptoarr(value)) != 0) return true;
	if (length(value) > 255) return false;
	let labels = split(value, ".");
	return (length(filter(labels, label => !match(label, /^([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9])$/))) == 0 && length(labels) > 0);
}

global.matchUcHost = matchUcHost;

function matchUcTimeout(value) {
	return match(value, /^[0-9]+[smhdw]$/);
}

global.matchUcTimeout = matchUcTimeout;

function matchUcBase64(value) {
	return b64dec(value) != null;
}

global.matchUcBase64 = matchUcBase64;

function matchUcPortrange(value) {
	let ports = match(value, /^([0-9]|[1-9][0-9]*)(-([0-9]|[1-9][0-9]*))?$/);
	if (!ports) return false;
	let min = +ports[1], max = ports[2] ? +ports[3] : min;
	return (min <= 65535 && max <= 65535 && max >= min);
}

global.matchUcPortrange = matchUcPortrange;

function matchHostname(value) {
	if (length(value) > 255) return false;
	let labels = split(value, ".");
	return (length(filter(labels, label => !match(label, /^([a-zA-Z0-9]{1,2}|[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9])$/))) == 0 && length(labels) > 0);
}

global.matchHostname = matchHostname;

function matchUcFqdn(value) {
	if (length(value) > 255) return false;
	let labels = split(value, ".");
	return (length(filter(labels, label => !match(label, /^([a-zA-Z0-9]{1,2}|[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9])$/))) == 0 && length(labels) > 1);
}

global.matchUcFqdn = matchUcFqdn;

function matchUcIp(value) {
	return (length(iptoarr(value)) == 4 || length(iptoarr(value)) == 16);
}

global.matchUcIp = matchUcIp;

function matchIpv4(value) {
	return (length(iptoarr(value)) == 4);
}

global.matchIpv4 = matchIpv4;

function matchIpv6(value) {
	return (length(iptoarr(value)) == 16);
}

global.matchIpv6 = matchIpv6;

function matchUri(value) {
	if (index(value, "data:") == 0) return true;
	let m = match(value, /^[a-z+-]+:\/\/([^\/]+).*$/);
	if (!m) return false;
	if (length(iptoarr(m[1])) != 0) return true;
	if (length(m[1]) > 255) return false;
	let labels = split(m[1], ".");
	return (length(filter(labels, label => !match(label, /^([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9])$/))) == 0 && length(labels) > 0);
}

global.matchUri = matchUri;

function newUConfigState(location, value, errors) {
	return value;
}

export function validate(value, errors) {
	let err = [];
	let res = newUConfigState("", value, err);
	if (errors) push(errors, ...map(err, e => "[E] (In " + e[0] + ") Value " + e[1]));
	return length(err) ? null : res;
};
