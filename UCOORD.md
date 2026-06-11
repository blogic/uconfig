# ucoord

Coordination daemon for managing multiple uconfig-managed devices
across a unetd mesh network. ucoord handles peer discovery, remote
configuration push/pull, include file synchronisation, and device
lifecycle operations (reboot, sysupgrade).

ucoord runs on a coordinator node. Peers are other uconfig devices
reachable through the same unetd network.


## Architecture

Three components:

- **ucoord daemon** (modules/ucoord/usr/sbin/ucoord) - connects to
  ubus and unetmsg, manages venues and peers, handles RPC requests.
- **CLI module** (modules/ucoord/usr/share/ucode/cli/modules/ucoord.uc)
  - interactive management of venues, peers, includes, and remote
  configuration editing.
- **WebSocket UI** (the generic webui module, package uconfig-mod-ui:
  modules/webui/usr/share/ucode/uconfig/webui/uwsd-handler.uc) - JSON-RPC 2.0
  interface served via uwsd for browser-based management. The webui server proxies
  the coordination methods to the ucoord ubus daemon when this package is installed.
  See [WEBUI.md](WEBUI.md) for the full protocol reference.

All inter-device communication happens over unetmsg pub/sub channels
within unetd networks. See [UCOORD-unetmsg.md](UCOORD-unetmsg.md)
for the wire-level message format.


## Venues and Peers

A **venue** is a unetd network registered for coordination. Venue
names are prefixed with ucoord_ internally (e.g. CLI venue "lab"
maps to unetd network "ucoord_lab"). Maximum venue name length is
8 characters.

Configuration source: /etc/uconfig/data/unetd.json - the
networks object maps venue names (with prefix) to network
definitions containing domain, key, and auth_key properties.

Each peer has a **state**:

| State | Meaning |
|-------|---------|
| pending | Initial state, or after peer list change |
| connected | Normal operating state |
| rebooting | Device is rebooting |
| upgrading | Firmware upgrade in progress |
| reconfiguring | Configuration apply in progress |

Peers are identified by their unetd host name. The daemon tracks
each peer's state, last-seen timestamp, capabilities, board info,
and include file UUIDs.


## Peer Discovery

1. When the daemon starts, it reads /etc/uconfig/data/unetd.json
   and joins each network as a venue
   (config_reload() in modules/ucoord/usr/sbin/ucoord).
2. For each venue, the daemon publishes and subscribes to the
   unetmsg channel.
3. On subscribe, the daemon sends an announce message containing
   its state, capabilities, board info, and include UUIDs.
4. When a peer's announce is received, it triggers a reciprocal
   announce if this is the first peer seen (initial announce).
5. Peer list changes (unetmsg callback) reset all peers to pending
   state, reload ACLs, and re-announce.

The local host's own peer entry is maintained directly from the
unetd network_get ubus call (venue.local_host).


## Access Control

ACLs are loaded from unetd service definitions
(acl_load() in modules/ucoord/usr/sbin/ucoord):

1. For each venue, query unetd for the network's service list.
2. Services with type: "ucoord" define authorised members.
3. When ACL members are defined, only listed peers may issue RPC
   requests. Unauthorised requests receive an "unauthorized" error
   response.
4. When no ucoord service is defined (empty ACL), all peers are
   authorised.

ACLs are reloaded on peer list changes and on reload.

The CLI venue create command automatically creates an admin
service of type ucoord with the creating host as the initial
member.


## Remote Configuration

Three actions via the configure handler
(handlers.configure in modules/ucoord/usr/sbin/ucoord):

| Action | Behaviour |
|--------|-----------|
| get | Reads /etc/uconfig/configs/uconfig.active on the peer and returns the parsed JSON |
| test | Writes config to /tmp/uconfig.pending, runs uconfig-apply -t, returns validation result |
| apply | Same as test, but on success also triggers deferred config apply via config_apply_deferred() |

Requests use an ID-based correlation mechanism: each outgoing
request gets a monotonically increasing ID, with a timeout timer.
Responses are matched by ID. The default timeout is 3000ms.

For local peers (where the peer is the coordinator itself),
handlers are called directly without going through unetmsg.


## Include Synchronisation

Include files are stored in /etc/ucoord/configs/ as JSON files.
Each file must contain a uuid property (an integer timestamp
used for ordering).

### Passive sync

Peers broadcast their include UUIDs in announce messages.
include_sync() (modules/ucoord/usr/sbin/ucoord) runs with a
2-second debounce timer after each announce:

1. Build a map of the newest UUID for each include name across all
   peers.
2. Compare against local includes - identify files that are missing
   or have an older UUID, and files that exist locally but no peer
   has.
3. Select the peer with the most needed files (to minimise the
   number of requests).
4. Send an include_request RPC to that peer, passing the list
   of needed file names.
5. On response, write received files and delete orphaned local files.
6. Trigger config_apply_deferred() to re-apply the active config
   with updated includes.

### Active push (edit mode)

When an include file is set or deleted via the include ubus
method, the daemon re-announces with include_edit: true and the
full include data attached to the announce message. Receiving
peers call include_apply() which writes the files directly and
triggers a deferred config re-apply, bypassing the normal sync
mechanism.

### Include resolution in uconfig

files/usr/share/ucode/uconfig/includes.uc resolves include
sources during the apply pipeline. Sources prefixed with ucoord:
resolve to /etc/ucoord/configs/$name.json. Deep-merge semantics
are the same as described in the [README.md Includes section](README.md#includes).


## ubus API

The daemon publishes the ucoord ubus object
(modules/ucoord/usr/sbin/ucoord).

| Method | Arguments | Description |
|--------|-----------|-------------|
| status | - | Returns { venues } with per-venue peer maps |
| reload | - | Reloads venues from /etc/uconfig/data/unetd.json, returns venue list |
| configure | venue, peer, action, config?, timeout? | Remote config get/test/apply |
| info | venue, peer, timeout? | Remote system info (uptime, memory) |
| capabilities | venue, peer, timeout? | Remote capabilities and wiphy data |
| include | venue?, action, name?, content?, timeout? | Include file CRUD (list/get/set/delete) |
| reboot | venue, peer | Send reboot command to peer |
| sysupgrade | venue, peer, url, action?, timeout? | Remote firmware upgrade |

See [UCOORD-ubus.md](UCOORD-ubus.md) for the full method reference.

All methods that contact a remote peer accept an optional timeout
argument (milliseconds, default 3000). Methods that perform remote
RPCs use deferred ubus replies.


## CLI

The CLI module registers a top-level ucoord command
(modules/ucoord/usr/share/ucode/cli/modules/ucoord.uc).

### Top-level commands

| Command | Description |
|---------|-------------|
| join | Join a coordination network (access-key, network required; netifd interface derived automatically) |
| status | Show venue/peer status overview |
| list | Peer table with venue, peer name, state, last seen |
| create venue $name | Create a new venue (network, optional password required) |
| delete venue $name | Delete a venue (prompts for password) |
| $peer | Select a peer directly from the top-level peer list |

### Venue context (select a venue)

| Command | Description |
|---------|-------------|
| status | Show venue details (network name, domain) |
| include | Enter include management context |
| invite | Invite a new host (hostname, access-key, optional password, timeout) |
| create host $name | Not available (hosts are added via invite) |
| delete host $name | Remove a host from the venue (prompts for password) |
| $host | Select a host for peer operations |

### Include context

| Command | Description |
|---------|-------------|
| list | List include files with UUIDs |
| show $name | Print include file contents |
| set $name file $path | Set include from a local JSON file |
| delete $name | Delete an include file |

### Peer context (select a host within a venue, or from top-level)

| Command | Description |
|---------|-------------|
| info | Show uptime, memory, connection details |
| state | Show ports, radios (from top-level peer selection: not available) |
| edit | Interactive remote config editing (fetches config, opens uconfig editor) |
| config status | Show current active config |
| config validate $file | Validate a local JSON config file on the peer |
| config push $file | Push and apply a local JSON config to the peer |
| reboot | Reboot the peer (confirmation prompt) |
| sysupgrade $url | Upgrade firmware on peer (confirmation prompt) |


## Service Integration

ucoord integrates with the uconfig service system by registering
unet as an assignable service
(modules/ucoord/usr/share/ucode/cli/modules/ucoord.uc).

When a venue is created or a network is joined, the CLI injects
"unet" into the specified interface's services list in the active
config (/etc/uconfig/configs/uconfig.active). This ensures the
unet service template is invoked for that interface during the
next apply.

When the last venue is destroyed (no networks remain in
/etc/uconfig/data/unetd.json), the unet service is removed from
all interface service lists in the active config.

The join command derives the netifd interface name from the
uconfig interface name by probing candidates (base name, then
_4 and _6 suffixes) against the netifd ubus interface status,
returning the first that is up and has an IP address.

The template modules/ucoord/usr/share/ucode/uconfig/templates/services/unet.uc
generates UCI configuration when interfaces reference the unet
service:

- Creates a unet firewall zone (input ACCEPT, output ACCEPT,
  forward REJECT).
- For each network in /etc/uconfig/data/unetd.json, creates a
  network interface with proto unet, domain, key, auth_key,
  local_network list, and metric.
- Enables the unet service when unet interfaces exist.
- Enables the ucoord daemon when networks are configured.
