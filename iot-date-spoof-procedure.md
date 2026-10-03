# Procedure: Diagnose an Offline IoT Device & (If Warranted) Time-Travel It Onto the Cloud

> Revised, diagnosis-first rework of a Gemini-generated plan (not kept in this repo).
> This version does **not** assume the
> cause, replaces the unreliable ARP-spoofing section with a clean gateway takeover,
> removes the original's internal contradictions, and gates the spoofing behind
> evidence that it can actually work.

Concrete running example: iRobot Roomba i7, MAC `50:14:79:07:BE:71`, that joins the
2.4 GHz Wi-Fi, gets a lease (e.g. `192.168.1.74`), exchanges a few packets, then drops
and never completes its MQTT-over-TLS (TCP 8883) connection to AWS IoT. The vacuum
motor itself works when started manually, so the battery/hardware is fine — this is a
**network/cloud-onboarding** failure.

---

## 0. Why the original plan is not safe to run as-is

| Original step | Problem | Fix in this version |
|---|---|---|
| "Root CA expired" | **Unverified hypothesis.** No packet capture confirms it. | Phase A captures the actual TLS alert first. |
| NTP spoof over UDP 123 | Assumes the device gets time from NTP *before* TLS. Many AWS-IoT devices take time from the TLS handshake (ServerHello) or HTTPS, so UDP 123 spoofing does nothing. | Phase A confirms the device actually emits NTP before building anything. |
| Static DHCP lease **and** ARP spoof | Two mechanisms for the same goal, fighting each other. | Phase B makes the Pi the Roomba's gateway cleanly; ARP spoof is a documented fallback only. |
| DNS rewrite of `*.pool.ntp.org` **and** PREROUTING NAT of UDP 123 | Redundant — the port-123 redirect catches every NTP request regardless of which hostname resolved. | Keep the NAT redirect; drop the DNS-NTP rewrite. |
| ARP spoofing as primary path | Flaky (gateway re-ARPs, entries age out) and can itself cause the very drops you're chasing. | Demoted to fallback with an explicit warning. |
| — | **Biggest unstated risk:** time-travel only helps if the device *already trusts* the root the server presents, and that root merely *expired*. If iRobot rotated to a newer root the 2018 firmware never shipped, a past clock fixes nothing. | Phase A.4 checks the served chain against the device's likely trust era before you commit. |

**Rule for this procedure: do not build any spoofing infrastructure until Phase A
produces the TLS alert and the served certificate chain.**

---

## 1. Environment

- **Gateway / DHCP:** Neufbox (ISP router). Supports MAC-based static leases; no per-client DNS, no NAT reflection.
- **AP:** TP-Link EAP110-Outdoor, bridge mode, SSID `EAP110-Outdoor-AP`, WPA2-AES, 20 MHz.
- **Worker host (the "Pi"):** `192.168.1.2` (`gruissan.local`). Reachable over SSH as `admin` (local sudoer) — this is the host the eventual package would drive via SSH. The machine you run this procedure *from* is **not** this host.
- **Target device:** Roomba i7, MAC `50:14:79:07:BE:71`. No admin access to it (closed firmware).

---

## FINDINGS — capture run 2026-10-03 11:01–11:04 (the original premise is DISPROVEN)

A scoped ARP-MITM + `tcpdump` capture of Roomba `192.168.1.74` during a full reboot/connect cycle showed:

- **TLS to AWS works.** The Roomba established a TLS session to `54.84.183.59:443` (`ec2-...-compute-1.amazonaws.com`, Amazon us-east-1 — iRobot's AWS IoT backend) and exchanged **sustained bidirectional application data** across several seconds. An expired/untrusted root CA would abort with an RST + TLS alert in the first 1–2 round-trips. That did **not** happen.
- **No NTP, no DNS, no 8883** in the entire capture (212 pkts). The device never emitted UDP 123 → the whole NTP-time-travel strategy would do **nothing**.
- **Traffic is MQTT-over-TLS on 443** (AWS IoT over 443/WebSockets), not 8883. The original "fails on 8883" assumption is wrong.
- The only connection churn was **server-initiated FINs at a regular ~6.66 s cadence** — but this coincided with the ARP-MITM and is most likely an artifact of our own interception disturbing the pre-existing connection, **not** a clean signal. Do not diagnose off it.

**Conclusion:** The offline symptom is **not** a TLS/certificate/time problem. The cert-expiry hypothesis and the NTP/DNS-spoof plan below are therefore **not the fix** and should not be executed. The spoofing machinery was torn down and the network restored. See "What to investigate instead" at the end.

The rest of this document is retained as a *generic* reference for the technique on some *other* device where a capture actually shows a client-side `certificate_expired` — not for this Roomba.

---

## Ground truth — recon already run on `192.168.1.2` (2026-10-03)

The Pi (`gruissan`, Raspberry Pi 5, Debian bookworm, kernel 6.12) was inspected live. This constrains the plan:

- **It is a wired leaf, not the gateway.** `default via 192.168.1.1 dev eth0`, `ip_forward=0`, single `eth0`. Its `wlan0` is **DOWN / rfkill-blocked** (no Wi-Fi country set).
- **Consequence:** the "Pi hosts a dedicated Wi-Fi segment as the Roomba's gateway" idea is **not feasible on this hardware** — there is no usable AP radio and only one interface. Positioning the Pi inline therefore means **ARP-spoof** (or a targeted rogue-DHCP handing out gateway=`192.168.1.2` for that MAC). ARP-spoof is the practical primary here, not the fallback — mind its fragility (Phase A.1).
- **The Roomba is already visible at L2** on `eth0`: `192.168.1.74 → 50:14:79:07:be:71` in the neighbor table. Same broadcast domain → ARP-spoof capture is viable.
- **No tooling is installed.** Install prerequisites first:
  ```bash
  # on 192.168.1.2 (Debian bookworm)
  sudo apt-get update
  sudo apt-get install -y tcpdump dsniff iptables   # dsniff provides arpspoof
  # add only if Phase A proves them needed:  dnsmasq chrony
  ```
  (`dsniff` ships `arpspoof`; `nftables` is the modern alternative to `iptables` if you prefer.)

A better long-term option than ARP-spoofing is to give the Pi a **second NIC (USB-Ethernet)** or a **managed switch with port mirroring / a VLAN**, so it can sit inline deterministically. Flagged for the packaging phase; not required to test the Roomba once.

---

## Phase A — Confirm the failure mode (do this before anything else)

The goal of Phase A is a packet capture that answers four questions. Everything downstream depends on the answers.

### A.0 — Rule out the boring causes first (no spoofing needed)

An 8-year-old 2.4 GHz-only client silently dropping right after associating is very often an L2/roaming problem, not a TLS problem. Check these before touching certificates — any one of them could be the whole bug:

1. **802.11w / PMF (Protected Management Frames).** Old clients choke on "required" PMF. On the EAP110, set PMF to *disabled* (not "optional") for this SSID, or give the Roomba its own SSID with PMF off.
2. **Band steering / fast-roaming (802.11r/k/v).** Disable for the test SSID. A client that associates then gets steered/deauthed looks exactly like "connects then drops."
3. **Two radios answering.** If both the Neufbox radio *and* the EAP110 broadcast the same 2.4 GHz SSID, the Roomba may roam between them and reset. For the test, bring up a dedicated SSID on **only one** radio.
4. **DHCP lease actually completing.** On the Neufbox, confirm the Roomba holds a lease the whole time (not flapping). On the Pi you can watch from a distance:
   ```bash
   # on 192.168.1.2
   sudo tcpdump -ni any ether host 50:14:79:07:BE:71 and \( port 67 or port 68 or arp \)
   ```
   Flapping ARP / repeated DHCP DISCOVER = L2 problem, stop here and fix the AP.
5. **In the iRobot app:** note the current firmware version and whether it reports "offline" instantly or after ~30–60 s. Instant = association/auth; delayed = cloud/TLS.

If A.0 fixes it, you are done — no time-travel required.

### A.1 — Get the Roomba's traffic to flow through the Pi

You cannot passively see the Roomba's unicast traffic to the internet from `192.168.1.2` unless the Pi is inline. Two ways, best first:

**Preferred — dedicated segment, Pi as gateway (deterministic, no spoofing):**
- Create an isolated SSID (ideally its own VLAN) on the EAP110 for the Roomba, with the Pi as its gateway/DHCP. If the EAP110 can't VLAN in bridge mode, run a small `dnsmasq` DHCP on the Pi bound to a dedicated interface/USB-Ethernet-or-Wi-Fi adapter and connect the Roomba's segment to it.
- All Roomba traffic now transits the Pi; capture and redirect are trivial and stable.

**Fallback — ARP spoof (only if you truly can't segment):**
- Bidirectional and continuous, Pi forwarding enabled. Scope strictly to the two IPs:
  ```bash
  # on 192.168.1.2 — FALLBACK ONLY
  sudo sysctl -w net.ipv4.ip_forward=1
  # Roomba <-> Neufbox, both directions:
  sudo arpspoof -i <iface> -t 192.168.1.74 192.168.1.1 &
  sudo arpspoof -i <iface> -t 192.168.1.1 192.168.1.74 &
  ```
- **Warning:** if forwarding or either spoof direction hiccups, the Roomba loses its gateway and drops — which is indistinguishable from the bug you're diagnosing. Prefer the segment method.

### A.2 — Capture

```bash
# on 192.168.1.2, while the Roomba is (re)booting via CLEAN-hold
sudo tcpdump -ni <iface> -w /tmp/roomba.pcap host 192.168.1.74
```
Let it run through a full connect attempt, then analyze (`tshark -r /tmp/roomba.pcap`).

### A.3 — Answer the four questions

1. **Does it emit NTP (UDP 123)?** To what host, and *before* the TLS attempt?
   - No NTP before TLS → the NTP-spoofing strategy is dead on arrival; the device times itself from TLS/HTTPS. Reconsider (see A.5).
2. **Does TLS to :8883 (or :443) start, and what's the alert?**
   ```bash
   tshark -r /tmp/roomba.pcap -Y 'tls.alert_message' \
     -T fields -e ip.src -e tls.alert_message.level -e tls.alert_message.desc
   ```
   - `certificate_expired (45)` **sent by the Roomba (client)** → client-side expiry → time-travel is plausible. ✅
   - `certificate_unknown (46)` / `unknown_ca (48)` from the client → the device does **not** have the presented root at all → time-travel will **not** help (see Phase D). ❌
   - `handshake_failure (40)` / `protocol_version (70)` → TLS version/cipher mismatch, not time. ❌
3. **What chain does the server present?** Capture the ServerHello certs:
   ```bash
   tshark -r /tmp/roomba.pcap -Y 'tls.handshake.type == 11' \
     -T fields -e x509sat.printableString -e x509af.notBefore -e x509af.notAfter
   ```
4. **Does the root's validity window bracket Jan 2023 but exclude Oct 2026?** If yes, a past clock revalidates it → proceed. If the server presents a *newer* root (notBefore after the device's firmware date), stop — see Phase D.

### A.5 — If there's no pre-TLS NTP

Then the device derives time from the TLS handshake itself. Spoofing UDP 123 is pointless; the remaining levers are: (a) confirm it's really a time problem at all (it may be A.0), or (b) accept that a pure network bypass may be impossible and consider the non-network routes in Phase D.

---

## Phase B — Position the Pi (only if Phase A says time-travel is viable)

Use the **dedicated-segment / Pi-as-gateway** setup from A.1. Keep it; it's also your capture and redirect point. Skip the Neufbox static-lease + ARP-spoof combo from the original — it's unnecessary once the Pi is the gateway, and the two together were contradictory.

If you are stuck on the ARP-spoof fallback, keep the bidirectional spoof from A.1 running and enable forwarding; do **not** also set a conflicting static lease expecting per-client DNS.

---

## Phase C — Serve the past date (gated on A.3.1 = "yes, NTP before TLS")

### C.1 — Fixed-date NTP responder
Serve a constant past timestamp (example target: **2023-01-15 12:00:00 UTC**) to any UDP 123 request, with no upstream sync. Options, simplest first:

- **Minimal responder** (purpose-built, returns a fixed time) — a small `scapy`/UDP script bound to 123, or
- **chrony in orphan/local mode** with the Pi's own clock temporarily set back (heavier; affects the host clock — isolate it).

Prefer the fixed-responder script so you don't move the Pi's real clock.

### C.2 — Redirect the Roomba's NTP to it
Because the Pi is the gateway, one PREROUTING rule catches NTP no matter which hostname the device resolved — **no DNS NTP rewrite needed**:
```bash
# on 192.168.1.2
sudo iptables -t nat -A PREROUTING -s 192.168.1.74 -p udp --dport 123 \
  -j REDIRECT --to-ports 123
```
Forward everything else (8883/443) normally to the Neufbox so the cloud connection can actually complete.

### C.3 — DNS sinkhole: only if needed
Only stand up `dnsmasq`/Pi-hole if Phase A showed the device needs a *specific* name redirected (rare). For NTP alone it is redundant with C.2 — skip it.

---

## Phase D — If time-travel can't work: the honest alternatives

If Phase A shows `unknown_ca`/`certificate_unknown`, a rotated root, or no pre-TLS NTP, a clock trick won't onboard the device. Then:

1. **Full MITM with a re-signed chain** — terminate TLS on the Pi and re-present a chain the device trusts. Only works if the device does *not* pin a specific leaf/key (many do); likely blocked by cert pinning on iRobot gear. Verify from the capture before investing.
2. **Vendor path** — check whether iRobot still serves firmware for the i7 and whether a factory reset + re-provision through the current app flow pulls a newer bootstrap. Sometimes the app pushes an updated trust bundle out-of-band.
3. **Accept EOL** — an 8-year-old device whose server-side roots moved past its baked-in trust store may simply be cloud-dead. Local-only operation (manual start) still works, which matches your observation.

---

## Phase E — Teardown (always)

```bash
# on 192.168.1.2
sudo iptables -t nat -F PREROUTING
sudo pkill -f arpspoof            # if the fallback was used
sudo sysctl -w net.ipv4.ip_forward=0   # if you enabled it
# stop the NTP responder / dnsmasq
```
Return the Roomba to the normal SSID/gateway and reboot it (hold CLEAN ~20 s) so it syncs real time.

---

## Phase F — Packaging note (future `homepi-server` component)

Intended generalization: a per-MAC "date-spoof" component the package drives on the Pi
(`192.168.1.2`) over SSH-as-admin, to onboard other legacy IoT devices.

Shape consistent with this repo's conventions (see `CLAUDE.md` → "Adding New Components"):

- `iot-datespoof.sh` — takes `<MAC> <spoofed-ISO-date>`; sets up the gateway position, fixed-date NTP responder, and scoped PREROUTING redirect; has a clean `--teardown`.
- `systemd/iot-datespoof@.service` — templated per device/MAC, so it's opt-in and auto-tears-down.
- Config file mapping `MAC → date` (and `MAC → segment`), rather than hardcoding.
- Wire into `debian/postinst.sh` (install disabled by default) / `prerm.sh` / `postrm.sh`.
- Update `package-release.yml` `prepare-deb` to copy the files, and `depends` for `iptables`/`tcpdump`/`dnsmasq` (or `chrony`).

**Design constraints to keep it defensible and non-disruptive:**
- Strictly per-MAC scoped; never a blanket redirect.
- Default off; must be explicitly enabled per device.
- Always ships teardown; the systemd template should restore state on stop.
- Only touches devices on the operator's own network — document that clearly.

This is a **Phase-3 proposal sketch**, not built. Confirm the Roomba case end-to-end
(Phase A → C) before generalizing it into the package.

---

## What to investigate instead (Roomba i7 offline, TLS proven working)

Since the robot reaches AWS IoT and completes TLS, the "offline" state in the app is almost certainly **above** the transport layer. In rough priority:

1. **App ↔ cloud device association.** The robot may be talking to the cloud while the app's link to *that robot* is stale. Try: in the iRobot app, remove the robot and re-add it; or sign out/in. This re-binds the device to the account without touching the robot's network.

2. **Network re-provisioning on the robot.** Put the robot into Wi-Fi setup mode (hold **HOME + SPOT** until it chimes, ~2 min re-provision) and re-run the app's "add robot" flow. This refreshes its cloud registration/credentials, which can silently expire.

3. **Intermittent 2.4 GHz association (the A.0 causes).** Even with TLS working in bursts, a flapping Wi-Fi link reads as "offline." On the EAP110 test SSID: disable **PMF/802.11w (required)**, **band-steering**, and **802.11r/k/v**; make sure only one radio broadcasts the SSID the robot uses. Watch L2 from the Pi:
   `sudo tcpdump -ni eth0 ether host 50:14:79:07:be:71 and \( arp or port 67 or port 68 \)`
   Repeated ARP/DHCP = link flap, not cloud.

4. **Account / firmware state.** A very old app build or a server-side account issue can show a healthy robot as offline. Confirm the app is current; check iRobot status for the account region.

What is **ruled out** by the capture: expired root CA, clock/NTP, DNS hijack need, and 8883 reachability. Don't spend time there.
