# uconfig WebSocket Interface

JSON-RPC 2.0 protocol reference for the uconfig web UI.

The webui module (`uconfig-mod-ui`) provides the single websocket server. It is a thin
JSON-RPC layer with one generic surface and two interchangeable backends, selected once
at server start:

- **standalone** (singleton): when the ucoord daemon is not present, the device methods
  act directly on the local device. There is no venue/peer addressing.
- **ucoord**: when the ucoord ubus daemon is present, the device methods are addressed to
  a peer via `{venue, peer}` and additional coordination methods become available.

The live-state methods (`devices`, `traffic`, `radios`, `ports`, `network`, `event-log`,
`memory`) always report on the device running the server, in either mode, and take no
venue/peer addressing. They read the `state` ubus object (package `uconfig-mod-state`),
`event` (package `uconfig`) and `memory` (package `umemd`).

Sources:
- modules/webui/usr/share/ucode/uconfig/webui/uwsd-handler.uc (generic + mode selection)
- modules/webui/usr/share/ucode/uconfig/webui/uwsd/state.uc (live state, both modes)
- modules/webui/usr/share/ucode/uconfig/webui/uwsd/local.uc (standalone backend)
- modules/webui/usr/share/ucode/uconfig/webui/uwsd/ucoord.uc (ucoord backend)
- modules/webui/usr/share/ucode/uconfig/webui/uwsd/jsonrpc.uc
- modules/webui/usr/share/ucode/uconfig/webui/uwsd/auth.uc
- modules/webui/usr/share/ucode/uconfig/webui/uwsd/upload.uc (HTTP PUT /upload/&lt;token&gt;)


## Connection

- **Endpoint:** ws://$host:80/uconfig
- **Subprotocol:** uconfig (must be included in the WebSocket handshake;
  connections without this subprotocol are rejected with code 1003)
- **Maximum message size:** 32 KB
- **Idle timeout:** 120 seconds (configured in
  modules/webui/etc/uwsd-uconfig-ui.conf)

On connect, the server sends an event after 200ms: setup-required when the active
config carries no top-level `webui` object, login-required otherwise. A device in
the setup state has no password yet, so it also answers authenticated methods
without a login until a config with the marker is applied (standalone only).


## Modes

The server runs in one of two modes, fixed at start and reported in the login result
as the `mode` field ("standalone" or "ucoord"):

- **standalone** - the device methods (config-get, config-test, config-apply, system-info,
  capabilities, reboot, factory-reset, sysupgrade) operate on the local device and take
  **no** venue/peer parameters. `sysupgrade` takes the two-phase token/upload/apply form
  described below rather than a `url`. `status` and `info` are registered and describe this device as the single
  peer of the venue `local`; the remaining coordination methods (list, include, reload)
  are not registered and return ERROR_METHOD_NOT_FOUND.
- **ucoord** - the same device methods are addressed to a peer and require `{venue, peer}`
  (plus `config` where applicable); the coordination methods are available.

The method parameter tables below describe the **ucoord** form. In standalone mode, omit
venue/peer; the target is always the local device.


## Authentication

Credentials are stored in /etc/uconfig/webui/credentials as JSON:

```json
{
  "admin": {
    "hash": "<sha512-hex>"
  }
}
```

The login method compares the SHA-512 hash of the supplied password
against the stored hash. Authentication state is per-connection;
there are no tokens or sessions.

Password constraints (enforced by change-password):
- Must not be empty
- Maximum length: 64 characters


## Request Format

Standard JSON-RPC 2.0 request:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "<method-name>",
  "params": { }
}
```


## Response Format

**Success:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": { }
}
```

**Error:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32603,
    "message": "description",
    "data": { }
  }
}
```


## Error Codes

| Code | Constant | Meaning |
|------|----------|---------|
| -32700 | ERROR_PARSE | JSON parse failure |
| -32600 | ERROR_INVALID_REQUEST | Missing jsonrpc: "2.0" or method field |
| -32601 | ERROR_METHOD_NOT_FOUND | Unknown method name |
| -32602 | ERROR_INVALID_PARAMS | Missing or invalid parameters |
| -32603 | ERROR_INTERNAL | Internal error, ubus call failure, or backend not available |
| -32001 | ERROR_LOGIN_REQUIRED | Method requires authentication |
| -32000 | ERROR_INVALID_PASSWORD | Login failed |


## Server-Initiated Events

Events are JSON-RPC notifications (no id field):

```json
{
  "jsonrpc": "2.0",
  "method": "<event-name>"
}
```

| Event | When | Params |
|-------|------|--------|
| login-required | 200ms after connection, on a configured device | none |
| setup-required | 200ms after connection, when the config has no top-level `webui` object | none |
| rebooting | reboot accepted, before the device goes down | none |
| factory-reset | factory-reset accepted | none |
| upgrading | sysupgrade apply accepted | none |
| sysupgrade-validation-success | uploaded image passed `sysupgrade --test` | { file_id } |
| sysupgrade-validation-failed | uploaded image failed validation | { error } |


## Method Availability

| Group | Methods | Modes |
|-------|---------|-------|
| Session | login, logout, change-password, ping | both |
| Live state | devices, traffic, cpu, thermal, radios, ports, network, event-log, memory | both, always the local device (needs uconfig-mod-state; memory needs umemd) |
| Wi-Fi | wifi-dynamic | both, always the local device (needs the wifi-dynamic package) |
| Device | config-get, config-test, config-apply, system-info, capabilities, reboot, sysupgrade | both (local execution in standalone; proxied to a peer in ucoord) |
| Device | factory-reset | standalone only |
| Coordination | status, info | both (self-described in standalone; proxied in ucoord) |
| Coordination | list, include, reload | ucoord only |

All methods except login require prior authentication. Methods absent in the current
mode return ERROR_METHOD_NOT_FOUND. In ucoord mode, device and coordination methods are
proxied to the ucoord daemon; a proxy failure returns ERROR_INTERNAL ("Failed to call
ucoord" or "ubus error: <status>").


## Methods

### login

Authenticate with the server. This is the only method that does not
require prior authentication.

**Params:** { "password": "..." }

**Result:** { "success": true, "mode": "standalone" | "ucoord" }

The mode field tells the client whether this is a standalone device or an
ucoord-backed coordinator (see Modes).

**Errors:** ERROR_INVALID_PASSWORD on wrong password,
ERROR_INVALID_PARAMS if password is missing.


### logout

End the authenticated session.

**Params:** none

**Result:** { "success": true }


### change-password

Change the admin password.

**Params:** { "password": "..." }

**Result:** { "success": true }

**Errors:** ERROR_INVALID_PARAMS if password is missing or does
not meet length constraints.


### ping

Connection keepalive.

**Params:** none

**Result:** { "success": true }


### devices

List known clients with ARP data for the local device.

**Params:** none

**Result:** Proxied from ubus state devices ({ arp: true }).

**Errors:** ERROR_INTERNAL if the state backend is unavailable.


### traffic

Per-interface traffic statistics for the local device.

**Params:** none

**Result:** Proxied from ubus state traffic.

**Errors:** ERROR_INTERNAL if the state backend is unavailable.


### cpu

CPU utilisation over the last ten minutes.

**Params:** none

**Result:** Proxied verbatim from ubus state cpu:
{ "interval_s": 5, "samples": 120, "usage": [ 12, 14, 9, ... ] }

`usage` is whole-percent busy time per sample, oldest first, aggregated across all cores.
Each entry is the true average over its own `interval_s` window, computed from /proc/stat
jiffy deltas, so it is utilisation and not a load average: it is bounded by 0 and 100, it
excludes uninterruptible sleep, and it carries no smoothing between samples.

`samples` is the capacity of the ring, not its current length. `usage` grows from empty to
that length after a restart, rather than being padded, so a short array means the daemon
has not been running ten minutes yet rather than that the CPU was idle. A sample is
dropped, leaving a gap in wall-clock coverage, when the counters go backwards.

**Errors:** ERROR_INTERNAL if the state backend is unavailable.


### thermal

Board temperatures over the last hour.

**Params:** none

**Result:** Proxied verbatim from ubus state thermal:
{ "interval_s": 30, "samples": 120, "sensors": [ { "name": "cpu-thermal",
"temp_c": 66.2, "history": [ 66.1, 66.2, ... ] } ] }

One entry per sensor, ordered by name, each carrying degrees Celsius to a tenth.
`temp_c` is the newest entry of `history` rather than a fresh read, so every figure in the
reply shares one clock. `history` is oldest first and, like `cpu`, grows to `samples`
rather than starting padded.

Sensors are whatever the board exposes, so the set differs per device and the names come
from the kernel: a thermal zone's `type` (`cpu-thermal`), or a hwmon's `name`
(`mt7915_phy0`), suffixed with the kernel's label or input number where one hwmon carries
several. A hwmon owned by a thermal zone is reported once, under the zone, since the two
interfaces are the same part. A sensor that appears late, as a radio's does when its phy
registers, joins with a shorter history; one that disappears is dropped.

No thresholds are reported, so a consumer cannot tell from this call what this board
considers hot.

**Errors:** ERROR_INTERNAL if the state backend is unavailable.


### wifi-dynamic

Temporary AP interfaces, spawned and torn down at runtime without touching the stored
configuration. One method, dispatched on `action`.

**Params:** `{ "action": "list" | "status" | "add" | "remove" | "update", ... }`

| action | further params | result |
|--------|----------------|--------|
| list   | none | `{ "networks": [ <entry>, ... ] }` |
| status | network | `<entry>`, or `{ network, "active": false }` |
| add    | network, ssid, key, encryption, bands, and optionally timeout | `{ "success": true }` |
| remove | network | `{ "success": true }` |
| update | network, timeout | `{ "success": true }` |

An entry is:

```json
{ "network": "guest", "active": true, "ssid": "Guest", "key": "hunter2hunter2",
  "encryption": "sae", "bands": [ "2g", "5g" ], "remaining": 3540 }
```

`bands` selects which radios carry it, matched against each radio's configured band, so a
network is spawned on every up radio that matches. `timeout` is seconds; without one the
network persists until removed. `remaining` is seconds left and is absent on a network
that has no expiry.

`key` is the plaintext PSK. It is returned deliberately: the session is already
authenticated and can read every wifi key through config-get, so withholding it here
would only stop a client displaying a password it just set.

Nothing here is persistent. The daemon holds its networks in memory, so a restart of it
drops every dynamic network, and none of this is written to the stored configuration.

**Errors:**
- ERROR_METHOD_NOT_FOUND when the wifi-dynamic package is absent.
- ERROR_INVALID_PARAMS for an unknown action, a missing required parameter, a network
  with no dynamic wifi on it (remove, update), a network that already carries one (add),
  or a value the daemon rejects. The daemon owns the value rules: ssid 1 to 32 characters,
  key 8 to 63, and the network must already exist in netifd. `update` also rejects a
  network that was created without a timeout, since it has no timer to retime.
- ERROR_INTERNAL for any other ubus failure, carrying the status in `data.status`.


### radios

Operating state per radio: the configured channel against the one the radio landed on,
plus airtime utilisation.

**Params:** none

**Result:** Proxied verbatim from ubus state radios. An object keyed by band as the
wireless config spells it, lowercase (2g, 5g, 6g). `channel` is what was asked for
("0" means automatic) and `active_channel` is what the radio chose.

**Errors:** ERROR_INTERNAL if the state backend is unavailable.


### ports

Physical socket state: carrier, negotiated speed and byte counters.

**Params:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| network | string | no | Narrow to the sockets one network holds; omit for all |

**Result:** Proxied verbatim from ubus state ports. An object keyed by socket label
(WAN, LAN1..LANn), each carrying netdev, index, carrier, speed, macaddr, rx_bytes and
tx_bytes. `speed` is null when there is no carrier, which is the normal unplugged state.

**Errors:** ERROR_INTERNAL if the state backend is unavailable.


### network

Addressing per uconfig document interface, as opposed to per netifd section.

**Params:** none

**Result:** Proxied verbatim from ubus state network. An object keyed by the interface
name the uconfig document uses (wan, main), each with up, uptime, device and optional
ipv4/ipv6 objects. Every address field is omitted rather than empty when absent.

**Errors:** ERROR_INTERNAL if the state backend is unavailable.


### event-log

The last 100 things the device did.

**Params:** none

**Result:** Proxied verbatim from ubus event log: { "log": [ { object, verb, time,
...payload } ] }. The array is in ring-buffer slot order, not time order, and is neither
sorted nor filtered on the way through; the vocabulary is open, so unrecognised
object/verb pairs are forwarded as they arrive. The buffer does not survive a restart.

**Errors:** ERROR_INTERNAL if the event daemon is unavailable.


### memory

Free memory, and which processes have grown since the watcher first saw them.

**Params:** none

**Result:** Proxied verbatim from ubus memory info: { system, leaking, stable }.
`leaking` is ordered by rss_delta_kb descending and `stable` by rss_kb descending; the
order is not changed on the way through. `system` is read at call time while the process
lists are resampled hourly, so the two halves are not the same age.

**Errors:** ERROR_METHOD_NOT_FOUND when the memory object is absent, which means the
umemd package is not installed rather than that the call failed.


### list

List all venues and their peers.

**Params:** none

**Result:** Proxied from ucoord ubus status method. Returns
{ "venues": { "$venue": { "$peer": { ... } } } }.


### status

Venue and peer status.

**Params:** none

**Result:** { "venues": { "$venue": { "$peer": { ... } } } }. In ucoord mode this is
identical to list. In standalone mode the server answers for itself: one venue named
`local` holding one peer named after the hostname, with state "connected", ts, the
capabilities object and the ubus system board reply.


### info

Query system information from a remote peer. In standalone mode this is an alias for
system-info and ignores venue/peer.

**Params:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| venue | string | yes | Venue name |
| peer | string | yes | Peer host name |
| timeout | integer | no | Timeout in milliseconds |

**Result:** Output of ubus call system info on the peer (uptime,
load, memory).


### system-info

Alias for info - identical behaviour.


### capabilities

Query device capabilities (board, model, MAC addresses, radio PHYs)
from a remote peer.

**Params:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| venue | string | yes | Venue name |
| peer | string | yes | Peer host name |
| timeout | integer | no | Timeout in milliseconds |

**Result:** Proxied from ucoord ubus capabilities method
({ capabilities, wiphy }).


### config-get

Retrieve the active configuration from a remote peer.

**Params:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| venue | string | yes | Venue name |
| peer | string | yes | Peer host name |
| timeout | integer | no | Timeout in milliseconds |

**Result:** In ucoord mode, the peer's active uconfig JSON document. In standalone
mode, the envelope { "config": <document>, "includes": { "<name>": <fragment> } },
carrying the contents of every include the document declares so a client can edit
a fragment and save it back without having seen it as a file.


### config-test

Validate a configuration on a remote peer without applying it.

**Params:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| venue | string | yes | Venue name |
| peer | string | yes | Peer host name |
| config | object | yes | Full uconfig JSON document |
| includes | object | no | Standalone only: fragment contents keyed by include name |
| timeout | integer | no | Timeout in milliseconds |

**Result:** Validation result from uconfig-apply -t.

In standalone mode each fragment is written before the config is rendered, to the
file the document's own top-level `includes` map resolves it to (`local:<name>` ->
/etc/uconfig/<name>.json, `ucoord:<name>` -> /etc/ucoord/configs/<name>.json). A
fragment with no `uuid` is stamped with one, since the loader rejects it otherwise.
A fragment whose name the document does not declare is an ERROR_INVALID_PARAMS.
Fragments the client omits are left alone rather than deleted.


### config-apply

Push and apply a configuration on a remote peer.

**Params:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| venue | string | yes | Venue name |
| peer | string | yes | Peer host name |
| config | object | yes | Full uconfig JSON document |
| includes | object | no | Standalone only: fragment contents keyed by include name |
| timeout | integer | no | Timeout in milliseconds |

**Result:** Validation result. The peer applies the config
asynchronously after responding. `includes` is handled exactly as for config-test.


### reboot

Reboot a remote peer.

**Params:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| venue | string | yes | Venue name |
| peer | string | yes | Peer host name |
| timeout | integer | no | Timeout in milliseconds |

**Result:** { "ok": true, "venue": "...", "peer": "..." }


### sysupgrade

Upgrade firmware. The two modes take entirely different parameters.

**Params (ucoord), the peer fetches the image itself:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| venue | string | yes | Venue name |
| peer | string | yes | Peer host name |
| url | string | yes | Firmware image URL |
| timeout | integer | no | Timeout in milliseconds |

**Params (standalone), two phases around an out-of-band upload:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| action | string | yes | `token` or `apply` |
| file_id | string | for apply | Identifier returned by the upload |
| keep_config | boolean | no | Keep configuration across the flash (apply only) |

`action: 'token'` returns { token, upload_url, max_size, expires_in }. The image is
then sent as an HTTP `PUT` to `upload_url` on the same host, which validates it with
`sysupgrade --test`, emits sysupgrade-validation-success or -failed, and answers 201
with a `file_id`. `action: 'apply'` flashes that file. Tokens are single use and
expire after 600 seconds; the image cap is 50 MB.

**Result:** Proxied from ucoord ubus sysupgrade method.


### include

Manage include files on a venue.

**Params:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| venue | string | yes | Venue name |
| action | string | yes | list, get, set, or delete |
| name | string | yes | Include file name |
| content | object | for set | Include file content |
| timeout | integer | no | Timeout in milliseconds |

**Result:** Depends on action - list returns a name-to-UUID map,
get returns the full include content, set and delete return
{ "ok": true }.


### reload

Reload the ucoord daemon configuration.

**Params:** none

**Result:** Proxied from ucoord ubus reload method.
