var id = 1;

function get_appropriate_ws_url(extra_url)
{
	var pcol;
	var u = document.URL;

	if (u.substring(0, 5) === "https") {
		pcol = "wss://";
		u = u.substr(8);
	} else {
		pcol = "ws://";
		if (u.substring(0, 4) === "http")
			u = u.substr(7);
	}

	u = u.split("/");

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
		sendmsg([
			'authenticate',
			document.getElementById("username").value,
			document.getElementById("password").value,
		]);
	}
	document.getElementById("login").addEventListener("click", sendlogin);

	function sendpasswd()
	{
		sendmsg([
			'password',
			id++,
			document.getElementById("password").value,
		]);
	}
	document.getElementById("passwd").addEventListener("click", sendpasswd);

	function sendcommand()
	{	
		let cmd = document.getElementById("command").value.split(' ');
		sendmsg([
			'command',
			id++,
			...cmd
		]);
	}
	document.getElementById("send").addEventListener("click", sendcommand);

	document.getElementById("trace").value = '';
}, false);
