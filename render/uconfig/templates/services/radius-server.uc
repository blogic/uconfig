{%-
	if (!services.is_present("radius"))
		return;

	let interfaces = services.lookup_interfaces("radius-server");
	let enable = length(interfaces);
	services.set_enabled("radius", enable);
	if (!enable)
		return;

	let radius = {
		secret: 'secret',
	};
	let data = fs.readfile('/etc/uconfig/data/radius.json');
	if (data)
		radius = json(data);

	let users = {
		"phase1": {
			"wildcard": [
				{
					"name": "*",
					"methods": [ "PEAP" ]
				}
			]
		},
		"phase2": {
			"users": { }
		}
	};

	for (let user, data in radius.user) {
		users.phase2.users[user] = data;
		users.phase2.users[user].methods = [ 'MSCHAPV2' ]
	}
	fs.writefile('/var/run/radius.users', users);
%}

# Configure MDNS
add radius radius 
set radius.@radius[0].ca_cert='/etc/uconfig/certificates/ca.pem'
set radius.@radius[0].cert='/etc/uconfig/certificates/cert.pem'
set radius.@radius[0].key='/etc/uconfig/certificates/cert.key'
set radius.@radius[0].users='/var/run/radius.users'
set radius.@radius[0].auth_port='1812'
set radius.@radius[0].acct_port='1813'
set radius.@radius[0].secret={{ s(radius.secret || 'secret') }}
set radius.@radius[0].ipaddr='0.0.0.0/0'
{%	for (let interface in interfaces): %}
add_list radius.@radius[0].network={{ s(interface.name) }}
{%	endfor %}
