# uconfig

Intent-based configuration for OpenWrt. A single JSON document declares
the desired device state - network interfaces, wireless radios, services,
firewall rules - and uconfig translates that intent into UCI packages,
generated files, and service lifecycle actions. The operator describes
*what* (e.g. "a downstream interface with WPA3 on 5 GHz") rather than
*how* (individual UCI options across network, wireless, firewall,
dhcp, ...).

Configuration is applied atomically: the entire document is validated
and rendered before any system state changes, and the previous
configuration is preserved for rollback.


## Apply Pipeline

uconfig-apply (files/usr/bin/uconfig-apply) drives the pipeline.
The high-level flow:

```
JSON input
  -> include resolution
    -> schema validation
      -> template rendering (UCI batch)
        -> shadow commit
          -> service lifecycle
```

### Steps in detail

1. **UUID assignment** - a Unix-timestamp UUID is written into the
   config unless -u (keep UUID) is set.

2. **File storage** - the config is written to
   /etc/uconfig/configs/uconfig.cfg.$uuid and the uconfig.pending
   symlink is pointed at it.

3. **Include resolution** - external fragments referenced in the
   includes object are loaded and deep-merged into the document
   (see [Includes](#includes) below).

4. **Schema validation** - the merged document is validated against
   the generated JSON Schema. Validation failures abort the apply.

5. **Template rendering** - Ucode templates under
   files/usr/share/ucode/uconfig/templates/ emit a UCI batch
   script written to /tmp/uconfig.uci.

6. **Shadow commit** - the UCI batch is imported into a shadow copy
   of /etc/config at /tmp/uconfig-shadow, committed there, then
   copied to the runtime UCI directory.

7. **Service lifecycle** - services no longer needed are stopped and
   disabled; services required by the new config are enabled and
   started (or reloaded/restarted as appropriate).

8. **Symlink rotation** - on success, uconfig.active is pointed at
   the new config and the old active config becomes uconfig.prev.

### Flags

| Flag | Effect |
|------|--------|
| -t | Test only - validate and render but do not apply |
| -n | Do not update the uconfig.active symlink |
| -u | Preserve the existing UUID |
| -r | Rollback to the previous active config on failure |
| -v | Verbose output |

Core implementation: files/usr/share/ucode/uconfig/uconfig.uc
(generate() function).


## Configuration

A uconfig document is a JSON object with these top-level keys:

| Key | Description |
|-----|-------------|
| uuid | Integer configuration identifier (Unix timestamp) |
| strict | Boolean; when true, warnings are promoted to errors |
| unit | Device identity: hostname, timezone, password, LED state, TTY login |
| radios | Named radio objects keyed by label (e.g. "2G", "5G", "6G"). Each specifies band, channel, mode (HT/VHT/HE/EHT), channel width, TX power |
| interfaces | Named logical interfaces (e.g. "wan", "lan", "guest"). Each declares a role (upstream/downstream), IP configuration, ports, SSIDs, VLANs, services |
| definitions | Shared objects referenced elsewhere: RADIUS servers, network prefixes, NTP servers |
| ethernet | Physical port configuration (speed, duplex) |
| services | Named service blocks (SSH, mDNS, LLDP, RADIUS, syslog, ...) referenced by interface services arrays |

### Schema sources

YAML schema fragments live under schema/ with schema/uconfig.yml
as the root. Run generate.sh to merge them into
generated/schema.json and produce the runtime validation modules.

The full schema reference is available as browsable HTML at
https://blogic.github.io/uconfig-new/, it is rebuilt
automatically on every push to main.


## Includes

Configurations can pull in shared fragments via the includes system
(files/usr/share/ucode/uconfig/includes.uc).

A top-level includes object maps names to sources:

```json
{
  "includes": {
    "shared": "ucoord:my-home",
    "site":   "local:site-overrides"
  }
}
```

### Source prefixes

| Prefix | Resolves to |
|--------|-------------|
| local: | /etc/uconfig/$name.json |
| ucoord: | /etc/ucoord/configs/$name.json |

Each source file must be valid JSON containing a uuid property.

### Referencing included data

Any object in the configuration may contain an include array listing
fragments to merge. Dot notation selects sub-paths within a source:

```json
{
  "ssids": {
    "guest": {
      "include": ["shared.ssid-profiles.guest"],
      "bss-mode": "ap"
    }
  }
}
```

Fragments are deep-merged: nested objects merge recursively, while
scalar values and arrays from the fragment overwrite the target.
The includes object and all include arrays are removed from
the document before validation.


## Setup Wizard

The setup wizard (files/usr/bin/uconfig-wizard) provides a guided,
interactive workflow for generating an initial uconfig configuration.
It walks through device mode (access point or router), root password,
hostname, timezone, wireless setup and services, then writes the
resulting JSON to /tmp/uconfig/ and optionally applies it via
uconfig-apply.

Wireless radios are auto-discovered from the hardware; the wizard
selects the best channel mode per band and applies fixed channel
widths (20 MHz for 2G, 80 MHz for 5G, 160 MHz for 6G). The user
only needs to provide an SSID, security level and password.

```
uconfig-wizard
```

## CLI

The interactive CLI (files/usr/share/ucode/cli/uconfig.uc and
modules under files/usr/share/ucode/cli/modules/uconfig/) provides
a structured editor for uconfig documents.

### Editor hierarchy

The top-level edit context contains nodes for each configuration
section:

- unit - hostname, timezone, password, LEDs
- radios - per-radio settings
- interfaces - per-interface settings, SSIDs, ports
- services - per-service configuration
- definitions - RADIUS servers, network prefixes
- includes - include source management

### Commit workflow

1. Edit fields through the CLI - each change sets an internal
   *changed* flag.
2. dry-run - writes the document to a temporary file and runs
   uconfig-apply -t to validate and render without applying.
3. commit - if not already dry-run tested, a dry-run is executed
   first automatically. On success the config is written and
   uconfig-apply is invoked to apply it.


## Daemons

### uconfig-event

files/usr/bin/uconfig-event

Captures real-time events from multiple sources into a circular buffer
(100 entries) exposed over ubus as the event object.

| Source | Events |
|--------|--------|
| hostapd | Client join (authorised), authentication failure (key mismatch), AP start/stop, channel switch |
| nl80211 | Client leave (with TX/RX stats and connected time) |
| RTNL | Network carrier up/down |
| dnsmasq | DHCP/DNS events |
| dropbear | SSH session events |

The daemon also handles rate-limit policy application and VLAN device
setup when clients associate.

### uconfig-state

modules/state/usr/bin/uconfig-state

Publishes runtime device state over ubus as the state object.

| Method | Returns |
|--------|---------|
| devices | Connected devices per network: fingerprint, hostname, IP addresses, traffic statistics |
| device_hostname, device_ignore, device_delete | Maintain the per-MAC device records |
| ports | Physical port status per role: carrier, speed, MAC, traffic counters |
| radios | Per-band radio status: channel, frequency, airtime utilisation, available channels per bandwidth |
| network | Addressing per document interface, grouped out of netifd by the uconfig_name stamp |
| traffic | WAN traffic rolling averages (2-minute, hourly, daily, weekly) |
| fingerprint_update | Refresh the fingerprint cache |

Device metadata (custom hostnames, ignore flags) is persisted in
/etc/uconfig/devices/ as per-MAC JSON files.


## Examples

Example configurations live under files/etc/uconfig/examples/.

| File | Description |
|------|-------------|
| default.json | Dual-band (2G/5G HE) AP with WAN upstream, LAN downstream, PSK2 encryption |
| dumb-ap.json | Single-interface access point with DHCP upstream |
| fingerprint.json | Adds device fingerprinting service to default setup |
| ieee8021x.json | 802.1X port authentication with RADIUS |
| initial.json | Minimal wired-only bootstrap with SSH and CLI |
| lldp.json | LLDP network discovery service |
| mesh-batman.json | Batman-adv mesh with dedicated mesh + AP SSIDs |
| multi-psk.json | Multiple pre-shared keys per SSID with MAC and VLAN assignment |
| owe-ap.json | Opportunistic Wireless Encryption (OWE transition mode) |
| radius-builtin.json | Built-in RADIUS server with enterprise SSID template |
| radius.json | External RADIUS server with enterprise authentication |
| ratelimit.json | Per-SSID ingress/egress rate limiting |
| vlan.json | VLAN-tagged secondary interface |
| wds-ap.json | WDS access point mode (5G HE) |
| wds-repeater.json | WDS repeater mode (5G) |
| webui.json | Single-interface AP offering the web UI, seeded on first boot when uconfig-mod-ui is installed |
| wifi-7.json | WiFi 7 (EHT) tri-band configuration (2G/5G/6G) |
| pppoe.json | PPPoE upstream |
| qos.json | Quality-of-service classification |
| tailscale.json | Tailscale service |
| wwan.json | WWAN/modem upstream |
