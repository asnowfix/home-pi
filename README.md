# home-pi

A home server meta-package for Raspberry Pi. Ships scripts, configuration files, and dependencies to turn a Raspberry Pi into a capable home server.

## What's Included

### USB Automount

Headless USB automount — automatically mounts USB drives to `/media/<label>-<device>` via udev rules.

#### Manual Installation (without .deb)

```bash
sudo ./install-usb-automount.sh
```

#### Troubleshooting

If USB drives are not mounting automatically, use the diagnostic script to analyze your system:

```bash
sudo diagnose-disks.sh
```

This will show:
- All block devices and their properties
- USB device detection
- udev attributes for disk devices
- Removable drive status
- Current mount points

Use this output to verify that your USB drives have the `removable=1` attribute required by the udev rules.

### Maestral Dropbox Client

[Maestral](https://maestral.app), an open-source Dropbox client for Linux, installed in an isolated Python venv.

After installation, set up Dropbox sync:

```bash
maestral auth link  # Link your Dropbox account
maestral start      # Start syncing
maestral status     # Check status
```

For more commands: `maestral --help`

## Debian Package

Install the meta-package to get everything configured at once:

```bash
sudo dpkg -i homepi-server_*.deb
```

See [debian/README.md](debian/README.md) for detailed package information.

See [PLAN.md](PLAN.md) for the roadmap of upcoming components (Prometheus, MQTT gateway, etc.).
