{%
	let interfaces = services.lookup_interfaces("ssh");
	let enable = length(interfaces);
	services.set_enabled("dropbear", !!enable);
	if (!enable)
		return;

	/* add all defined ssh keys */
	ssh.authorized_keys ??= [];
	for (let key in board.credentials?.ssh_authorized_keys) {
		push(ssh.authorized_keys, key);
		ssh.password_authentication = false;
		warn('adding ssh authorized key from board.json\n');
	}
	files.add_named("/etc/dropbear/authorized_keys", join("\n", ssh.authorized_keys || []) + "\n");
%}

# Configure SSH
set dropbear.@dropbear[-1].enable={{ b(enable) }}
set dropbear.@dropbear[-1].Port={{ s(ssh.port) }}
set dropbear.@dropbear[-1].PasswordAuth={{ s(ssh.password_authentication ? 'on' : 'off') }}
set dropbear.@dropbear[-1].RootPasswordAuth={{ s(ssh.password_authentication ? 'on' : 'off') }}
{%
	/* open the port on all interfaces that select ssh */
	for (let interface in interfaces):
		let name = interface.name;
%}

# Configure SSH Firewall
add firewall rule
set firewall.@rule[-1].name='Allow-ssh-{{ name }}'
set firewall.@rule[-1].src='{{ name }}'
set firewall.@rule[-1].dest_port='{{ ssh.port }}'
set firewall.@rule[-1].proto='tcp'
set firewall.@rule[-1].target='ACCEPT'
{%	endfor %}
