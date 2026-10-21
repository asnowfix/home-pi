# Roomba i7 — local (cloud-independent) control

Control the home Roomba i7 **"Edmond"** directly on the LAN with the
[dorita980](https://github.com/koalazak/dorita980) local API — no iRobot cloud,
no app-online requirement. Built while diagnosing why the robot shows **offline**
in the iRobot app.

## TL;DR diagnosis (2026-10-03)

The app shows the robot offline, but **it is not a TLS/certificate/time problem.**
A scoped packet capture (see `capture/`) proved the robot completes a healthy TLS
session to AWS IoT (`54.84.183.59:443`) and exchanges application data — and its
firmware is from **2023-10-03**, not 8 years old. The "expired root CA → spoof NTP
to time-travel" idea from the original Gemini plan is therefore **wrong for
this robot**; full write-up and disproof in `../iot-date-spoof-procedure.md`.

Because local control works independently of the cloud, we can still command it.

## Status: credentials captured & validated (2026-10-21)

Local control is **working**: the password was captured and a live `getRobotState`
connected successfully. The robot's cloud link is down (`connected:false`) while
local control works — which is the whole point. The password lives only in
`roomba-creds.json` (gitignored) + a durable copy at `~/.homepi/roomba-creds.json`.

The robot's **IP is DHCP-assigned and changes** (it moved 192.168.1.74 → .50 once),
so the scripts resolve it **live by broadcast discovery matching the BLID** — no
IP is hardcoded. Override with `ROOMBA_HOST` if needed; consider a DHCP reservation
for the robot's MAC.

## Usage

Prereqs: a machine on the same LAN as the robot with Node ≥18.

```bash
cd roomba
npm install                 # pulls dorita980
npm start                   # == node start.js  -> full-home clean using saved creds
```

First-time only (no creds yet): put Edmond on its dock, powered on; press & HOLD
the HOME (house) button ~2s until it plays tones; release (Wi-Fi light flashes);
then within ~2 minutes run `npm run clean` (`node go.js`) — it fetches+saves the
password, then starts a clean. After that, `npm start` cleans with no button press.

Password parsing note: the password is extracted as the **longest printable-ASCII
run** from the magic-packet response. dorita980's built-in fixed-offset slice is
wrong for this i7 (it yields a bad password that fails auth), so `lib.js` does the
printable-run extraction instead.

Other commands: `npm run discover` prints the robot's current public info/IP;
`npm run getpass` just captures the password without cleaning.

## Files

| File | What |
|---|---|
| `robot.json` | Robot identity (name, **blid**, MAC, SKU, firmware). Non-secret; blid is discoverable on-LAN. No IP (discovered live). |
| `lib.js` | Shared helpers: broadcast IP discovery by blid, password fetch (printable-run parse), connect retries. |
| `discover.js` | On-LAN UDP discovery → prints robot public info + current IP. No creds/button. |
| `getpass.js` | Fetch the local password (needs the HOME-button press). Saves `roomba-creds.json`. |
| `go.js` | One-shot: get/reuse password → connect → **start full clean**. |
| `start.js` | Repeat cleans from saved creds (cron-friendly). |
| `roomba-creds.json` | **Secret**, gitignored — created on first `go.js`/`getpass.js`. The robot's local password. |
| `capture/` | Pi-side diagnostic MITM capture scripts + the 2026-10-03 pcap. |

Persistent map (for future room-targeted cleaning): `pmap_id e8EOWqiwQ6e8sGpyYU4C-w`
(map-version token `260829T114918`), from the robot's live state.

## Diagnostic capture (reference / other issues)

The `capture/*.sh` scripts run **on the Pi** (`192.168.1.2`) and need
`tcpdump` + `dsniff`:

```bash
sudo apt-get install -y tcpdump dsniff iptables   # already installed on the Pi
capture/start.sh     # ARP-MITM + tcpdump, scoped to the robot's IP only
capture/status.sh    # packet count / running state
capture/stop.sh      # TEARDOWN — kills spoof, restores ip_forward, heals ARP
```
ARP-spoofing is intrusive and can itself disturb the connection; `stop.sh` always
restores state. Scoped to the one robot IP, nothing else on the LAN is touched.

## Security notes

- `roomba-creds.json` holds the robot's local password — keep it out of git (it is,
  via `.gitignore`) and off shared storage.
- Everything here is local control of your own device on your own network.

## Possible future work

- Package as a homepi-server component driven from the Pi (systemd + optional
  schedule for routine cleans). Sketch in `../iot-date-spoof-procedure.md` (Phase F).
- Expose simple status (battery, bin, mission) via dorita980's `getRobotState`.
