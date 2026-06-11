# uconfig WebSocket Interface

JSON-RPC 2.0 protocol reference for the uconfig web UI.

The webui module (`uconfig-mod-ui`) provides the single websocket server. It is a thin
JSON-RPC layer with one generic surface and two interchangeable backends, selected once
at server start:

- **standalone** (singleton): when the ucoord daemon is not present, the device methods
  act directly on the local device. There is no venue/peer addressing.
- **ucoord**: when the ucoord ubus daemon is present, the device methods are addressed to
  a peer via `{venue, peer}` and additional coordination methods become available.

`devices`/`traffic` always read local data via the `state` ubus object
(package `uconfig-mod-state`).

Sources:
- modules/webui/usr/share/ucode/uconfig/webui/uwsd-handler.uc (generic + mode selection)
- modules/webui/usr/share/ucode/uconfig/webui/uwsd/local.uc (standalone backend)
- modules/webui/usr/share/ucode/uconfig/webui/uwsd/ucoord.uc (ucoord backend)
- modules/webui/usr/share/ucode/uconfig/webui/uwsd/jsonrpc.uc
- modules/webui/usr/share/ucode/uconfig/webui/uwsd/auth.uc


## Connection

- **Endpoint:** ws://$host:80/uconfig
- **Subprotocol:** ui (must be included in the WebSocket handshake;
  connections without this subprotocol are rejected with code 1003)
- **Maximum message size:** 32 KB
- **Idle timeout:** 120 seconds (configured in
  modules/webui/etc/uwsd-uconfig-ui.conf)

On connect, the server sends a login-required event after 200ms to
prompt authentication.


## Modes

The server runs in one of two modes, fixed at start and reported in the login result
as the `mode` field ("standalone" or "ucoord"):

- **standalone** - the device methods (config-get, config-test, config-apply, system-info,
  capabilities, reboot, sysupgrade) operate on the local device and take **no** venue/peer
  parameters. The coordination methods (list, status, info, include, reload) are not
  registered and return ERROR_METHOD_NOT_FOUND.
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
- Minimum length: 8 characters
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
| login-required | Immediately after connection | none |


## Method Availability

| Group | Methods | Modes |
|-------|---------|-------|
| Session | login, logout, change-password, ping | both |
| Local state | devices, traffic | both (needs uconfig-mod-state) |
| Device | config-get, config-test, config-apply, system-info, capabilities, reboot, sysupgrade | both (local execution in standalone; proxied to a peer in ucoord) |
| Coordination | list, status, info, include, reload | ucoord only |

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


### list

List all venues and their peers.

**Params:** none

**Result:** Proxied from ucoord ubus status method. Returns
{ "venues": { "$venue": { "$peer": { ... } } } }.


### status

Identical to list - returns venue/peer status.

**Params:** none

**Result:** Same as list.


### info

Query system information from a remote peer.

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

**Result:** The peer's active uconfig JSON document.


### config-test

Validate a configuration on a remote peer without applying it.

**Params:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| venue | string | yes | Venue name |
| peer | string | yes | Peer host name |
| config | object | yes | Full uconfig JSON document |
| timeout | integer | no | Timeout in milliseconds |

**Result:** Validation result from uconfig-apply -t.


### config-apply

Push and apply a configuration on a remote peer.

**Params:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| venue | string | yes | Venue name |
| peer | string | yes | Peer host name |
| config | object | yes | Full uconfig JSON document |
| timeout | integer | no | Timeout in milliseconds |

**Result:** Validation result. The peer applies the config
asynchronously after responding.


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

Upgrade firmware on a remote peer.

**Params:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| venue | string | yes | Venue name |
| peer | string | yes | Peer host name |
| url | string | yes | Firmware image URL |
| timeout | integer | no | Timeout in milliseconds |

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
