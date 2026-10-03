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

## Finish the job (when physically near the robot)

Prereqs: a machine on the same LAN as the robot (`192.168.1.74`) with Node ≥18.

```bash
cd roomba
npm install                 # pulls dorita980
# Put Edmond on its dock, powered on. Press & HOLD the HOME (house) button
# ~2 seconds until it plays a series of tones; release. The Wi-Fi light flashes.
# Then, within ~2 minutes:
npm run clean               # == node go.js  -> fetches+saves password, starts a full-home clean
```

`go.js` fetches the local password once (dorita980 v2 magic packet), saves it to
`roomba-creds.json` (gitignored), connects over MQTT-TLS to `:8883`, and sends
`start`. After that first run the password is cached, so every later clean is just:

```bash
npm start                   # == node start.js  (no button press needed)
```

## Files

| File | What |
|---|---|
| `robot.json` | Robot identity (name, **blid**, IP, MAC, SKU, firmware). Non-secret; blid is discoverable on-LAN. |
| `discover.js` | On-LAN UDP discovery → prints robot public info. No creds/button. |
| `getpass.js` | Fetch the local password (needs the HOME-button press). Saves `roomba-creds.json`. |
| `go.js` | One-shot: get/reuse password → connect → **start full clean**. |
| `start.js` | Repeat cleans from saved creds (cron-friendly). |
| `roomba-creds.json` | **Secret**, gitignored — created on first `go.js`. The robot's local password. |
| `capture/` | Pi-side diagnostic MITM capture scripts + the 2026-10-03 pcap. |

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
