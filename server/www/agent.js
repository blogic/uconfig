

function get_appropriate_ws_url(extra_url)
{
	var pcol;
	var u = document.URL;

	/*
	 * We open the websocket encrypted if this page came on an
	 * https:// url itself, otherwise unencrypted
	 */

	if (u.substring(0, 5) === "https") {
		pcol = "wss://";
		u = u.substr(8);
	} else {
		pcol = "ws://";
		if (u.substring(0, 4) === "http")
			u = u.substr(7);
	}

	u = u.split("/");

	/* + "/xxx" bit is for IE10 workaround */

	return pcol + u[0] + "/" + extra_url;
}

function new_ws(urlpath, protocol)
{
	return new WebSocket(urlpath, protocol);
}

function trace_add(msg)
{
	document.getElementById("trace").value =
		document.getElementById("trace").value + msg + '\n';
	document.getElementById("trace").scrollTop =
		document.getElementById("trace").scrollHeight;
}

function uploadFile() {
	let file = document.querySelector('#upload').files[0];
	let body = new FormData();

	body.append('upload', file);

	fetch(`/upload`, { method: 'POST', body })
		.then(response => {
			if (!response.ok)
				return response.text().then(error => Promise.reject(error));

			return response.json();
		});

		document.querySelector('#upload').value = '';
}

document.addEventListener("DOMContentLoaded", function() {

	var ws = new_ws(get_appropriate_ws_url("config"), "config");
	try {
		ws.onmessage = function(msg) {
			var j = JSON.parse(msg.data);
			if (j?.action == 'config' && j?.method == 'get')
				document.getElementById("config").value = JSON.stringify(j.params.config);
			else
				trace_add(msg.data);
		};

		ws.onopen = function() {
		},

		ws.onclose = function(){
		};
	} catch(exception) {
		alert("<p>Error " + exception);
	}

	function sendmsg(msg) {
		msg = JSON.stringify(msg);
		trace_add(msg);
		ws.send(msg);
	}

	function sendlogin()
	{
		sendmsg({
			uconfig: 1,
			action: 'user',
			method: 'authenticate',
			params: {
				username: document.getElementById("username").value,
				password: document.getElementById("password").value,
			}
		});
	}
	document.getElementById("login").addEventListener("click", sendlogin);

function sendpasswd()
	{
		sendmsg({
			uconfig: 1,
			action: 'user',
			method: 'password',
			params: {
				username: document.getElementById("username").value,
				password: document.getElementById("password").value,
			}
		});
	}
	document.getElementById("passwd").addEventListener("click", sendpasswd);

function sendreboot()
	{
		sendmsg({
			uconfig: 1,
			action: 'system',
			method: 'reboot',
		});
	}
	document.getElementById("reboot").addEventListener("click", sendreboot);

function sendsysupgrade()
	{
		sendmsg({
			uconfig: 1,
			action: 'system',
			method: 'sysupgrade',
		});
	}
	document.getElementById("sysupgrade").addEventListener("click", sendsysupgrade);

function senddelete_upgrade()
	{
		sendmsg({
			uconfig: 1,
			action: 'system',
			method: 'delete_upgrade',
		});
	}
	document.getElementById("delete_upgrade").addEventListener("click", senddelete_upgrade);

function sendfactory()
	{
		sendmsg({
			uconfig: 1,
			action: 'system',
			method: 'factory',
		});
	}
	document.getElementById("factory").addEventListener("click", sendfactory);

function sendget()
	{
		sendmsg({
			uconfig: 1,
			action: 'config',
			method: 'get',
		});
	}
	document.getElementById("get").addEventListener("click", sendget);

function sendlist()
	{
		sendmsg({
			uconfig: 1,
			action: 'config',
			method: 'list',
		});
	}
	document.getElementById("list").addEventListener("click", sendlist);

function sendconfirm()
	{
		sendmsg({
			uconfig: 1,
			action: 'config',
			method: 'confirm',
		});
	}
	document.getElementById("confirm").addEventListener("click", sendconfirm);

function sendset()
	{
		sendmsg({
			uconfig: 1,
			action: 'config',
			method: 'upload',
			params: {
				config: JSON.parse(document.getElementById("config").value)
			}
		});
	}
	document.getElementById("set").addEventListener("click", sendset);

function sendclients()
	{
		sendmsg({
			uconfig: 1,
			action: 'get',
			method: 'clients',
		});
	}
	document.getElementById("clients").addEventListener("click", sendclients);

function sendports()
	{
		sendmsg({
			uconfig: 1,
			action: 'get',
			method: 'ports',
		});
	}
	document.getElementById("ports").addEventListener("click", sendports);

function sendssids()
	{
		sendmsg({
			uconfig: 1,
			action: 'get',
			method: 'ssids',
		});
	}
	document.getElementById("ssids").addEventListener("click", sendssids);

function sendapply()
	{
		sendmsg({
			uconfig: 1,
			action: 'config',
			method: 'apply',
			params: {
				uuid: document.getElementById("uuid").value,
				rollback: document.getElementById("rollback").checked
			}
		});
	}
	document.getElementById("apply").addEventListener("click", sendapply);


	document.getElementById("trace").value = '';
	document.getElementById("config").value = '';
}, false);
