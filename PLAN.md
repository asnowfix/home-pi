# PLAN.md — homepi-server Roadmap

Turn a Raspberry Pi into a full home server by incrementally adding components to the `homepi-server` meta-package. Each phase ships as a new minor version.

---

## Phase 0 — Foundation (current state)

**Status:** Done

What's shipped today:
- [x] USB automount via udev rules (`usb-automount.sh`, `99-usb-automount.rules`)
- [x] Diagnostic tooling (`diagnose-disks.sh`)
- [x] Maestral Dropbox sync client (Python venv at `/opt/maestral-venv/`)
- [x] Google Drive sync via rclone + inotify (`rclone-gdrive-watch.sh`, `systemd/rclone-*`)
  - push: inotify watches `/data/GoogleDrive` → `gdrive:` with 5s debounce
  - pull: systemd timer polls `gdrive:` → `/data/GoogleDrive` every 30s via bisync
- [x] Debian meta-package build pipeline (`homepi-server` ARM64 .deb)
- [x] Orchestrator-pattern CI/CD (tag → build → draft release)
- [x] Manual install path (`install-usb-automount.sh`)

---

## Phase 1 — Monitoring: Prometheus

**Goal:** System-level metrics collection and dashboarding.

### Steps

1. **Install Prometheus**
   - Add `prometheus` to package dependencies or ship a pinned binary
   - Drop a default `prometheus.yml` config targeting localhost exporters
   - Create systemd unit file or enable the packaged one
   - Wire into `postinst.sh` (enable + start service) and `prerm.sh` (stop service)

2. **Install Node Exporter**
   - Ship `prometheus-node-exporter` as a dependency
   - Configure Prometheus to scrape `localhost:9100`

3. **Optional: Grafana**
   - Evaluate shipping Grafana or providing a companion install script
   - Provide pre-built dashboard JSON for Pi system metrics

### Files to add/modify
- `prometheus/prometheus.yml` — default scrape config
- `prometheus/prometheus.service` (if not using distro package)
- `debian/postinst.sh` — enable & start Prometheus + Node Exporter
- `debian/prerm.sh` — stop services
- `debian/postrm.sh` — cleanup config on purge
- `.github/workflows/package-release.yml` — copy new files into `.debpkg/`, update `depends`

---

## Phase 2 — IoT Bridge & Home Automation

**Goal:** Bridge IoT sensors and home automation into the home server using [asnowfix/home-automation](https://github.com/asnowfix/home-automation).

### Steps

1. **Integrate asnowfix/home-automation**
   - Pull or package the home-automation project as a dependency
   - Ship its configuration files and scripts into the meta-package
   - Wire into postinst/prerm lifecycle (enable & start services, stop on removal)

2. **Prometheus integration**
   - Configure Prometheus (from Phase 1) to scrape metrics exposed by home-automation
   - Add scrape targets to `prometheus/prometheus.yml`
   - Note: the MQTT-Prometheus gateway is a dependency of the home-automation package itself — no need to ship it here

3. **Documentation**
   - How homepi-server and home-automation interact
   - Configuration and customization of the home-automation setup

### Files to add/modify
- Config/scripts from `asnowfix/home-automation` → `.debpkg/` in package build
- `prometheus/prometheus.yml` — add home-automation scrape targets
- Debian lifecycle scripts — manage home-automation services

### Provided by asnowfix/home-automation (not shipped here)
- MQTT-Prometheus gateway (dependency of the home-automation package)
- Grafana + dashboards for home devices (dependency of the home-automation package)

---

## Phase 3 — Storage & Data

**Goal:** Reliable storage management for a home server.

### Steps

1. **Persistent mount configuration**
   - Extend USB automount to optionally write fstab entries for known drives
   - Support mount-by-label or mount-by-UUID for persistence across reboots

2. **Samba / NFS file sharing**
   - Ship `samba` or `nfs-kernel-server` as optional dependency
   - Provide default share config pointing at `/media/` mount points
   - Wire into postinst/prerm lifecycle

3. **Backup tooling**
   - Evaluate `restic`, `borgbackup`, or `rsnapshot`
   - Ship a cron job or systemd timer for scheduled backups
   - Provide a default config targeting mounted USB drives

---

## Phase 4 — Extended Home Automation

**Goal:** Expand the home-automation integration with additional device support.

### Steps

1. **Zigbee/Z-Wave USB support**
   - Ship udev rules for common Zigbee/Z-Wave USB sticks (same pattern as USB automount)
   - Wire into asnowfix/home-automation device discovery

### Provided by asnowfix/home-automation (not shipped here)
- Grafana dashboards for home devices (sensor overview, device status, historical trends)

---

## Phase 5 — Hardening & Ops

**Goal:** Make the home server production-ready for long-term unattended operation.

### Steps

1. **Automatic updates**
   - Ship `unattended-upgrades` config scoped to security updates
   - Provide a safe apt source for homepi-server package updates (GitHub Releases as apt repo, or Packagecloud)

2. **Log management**
   - Configure log rotation for all homepi-server components
   - Evaluate shipping `promtail` + Loki for centralized logging (pairs with Grafana from Phase 1)

3. **Health checks**
   - Ship a `homepi-health` script that verifies all enabled components are running
   - Optionally expose health as a Prometheus metric

4. **Firewall**
   - Ship a default `ufw` or `nftables` config allowing only the ports used by enabled components

---

## Adding a New Component — Checklist

When adding any new component, follow this pattern:

1. [ ] Add scripts/config to repo (root or subdirectory)
2. [ ] Update `package-release.yml` → `prepare-deb` step to copy into `.debpkg/`
3. [ ] Update `debian/postinst.sh` to install/enable/start
4. [ ] Update `debian/prerm.sh` to stop
5. [ ] Update `debian/postrm.sh` to clean up
6. [ ] Add system dependencies to `depends` in `build-deb` step
7. [ ] Update README.md with usage docs
8. [ ] Update CLAUDE.md if architecture changes
9. [ ] Tag a new minor version to release
