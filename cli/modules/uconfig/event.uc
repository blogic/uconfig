import * as uconfig from 'cli.uconfig';
import { basename, glob } from 'fs';

global.status_msg = model.cb.status_msg;

function subscriber_notify_cb(notify) {
	global.status_msg(notify.data);
}

function subscriber_remove_cb(remove) {
}

let subscriber = uconfig.ubus.subscriber(subscriber_notify_cb, subscriber_remove_cb);
let subscribed = false;

function listener_cb(event, payload) {
	if (payload.path != event)
		return;
	subscriber.subscribe(path);
}

function subscribe_events(ctx) {
	if (subscribed)
		return ctx.error('ALREADY_SUBSCRIBED', 'You are already subscribed');
	
	uconfig.ubus.listener('ubus.object.add', listener_cb);
	subscriber.subscribe('event');

	return ctx.ok('Done');
}

const ucEvent = {
	log: {
		help: 'List all example configurations',
		call: function(ctx, argv) {
			let log = uconfig.ubus.call('event', 'log');

			printf('%.J\n', log.log);

			return ctx.ok('Done');
		}
	},

	subscribe: {
		help: 'Subscribe to live events',
		call: function(ctx, argv) {
			return subscribe_events(ctx);
		}
	},
};
model.add_node('ucEvent', ucEvent);

const uConfig = {
	event: {
		help: 'Look at system events and logs',
		select_node: 'ucEvent',
	},
};
model.add_node('uConfig', uConfig);
