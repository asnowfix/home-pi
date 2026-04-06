# home-pi

Utilities and scripts for Rapsberry PI @ Home

## USB Automount

USB automount script for headless Raspberry Pi

### Installation

```bash
sudo ./install-usb-automount.sh
```

### Troubleshooting

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

## Maestral Dropbox Client

The package includes [Maestral](https://maestral.app), an open-source Dropbox client for Linux.

After installation, set up Dropbox sync:

```bash
maestral auth link  # Link your Dropbox account
maestral start      # Start syncing
maestral status     # Check status
```

For more commands: `maestral --help`

## Debian Package

The Debian package includes both USB automount and Maestral Dropbox client.

See [debian/README.md](debian/README.md) for detailed package information.
