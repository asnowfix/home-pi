# Debian Package Maintainer Scripts

This directory contains the maintainer scripts used during Debian package installation, upgrade, and removal.

## Files

- **postinst.sh** - Post-installation script
  - Creates log file `/var/log/usb-automount.log`
  - Creates `/media` directory
  - Reloads udev rules to activate USB automount
  - Installs Maestral Dropbox client in Python virtual environment at `/opt/maestral-venv`
  - Creates symlink `/usr/local/bin/maestral` for system-wide access

- **prerm.sh** - Pre-removal script
  - Runs before package removal or upgrade
  - Stops Maestral daemon if running

- **postrm.sh** - Post-removal script
  - Reloads udev rules after removal
  - Removes Maestral virtual environment and symlink
  - On purge, can optionally remove log files and Maestral config (commented out for safety)

## Package Structure

The Debian package installs:
- `/usr/local/bin/usb-automount.sh` - Main automount script
- `/usr/local/bin/diagnose-disks.sh` - Diagnostic script for troubleshooting
- `/etc/udev/rules.d/99-usb-automount.rules` - Udev rule for USB device detection
- `/opt/maestral-venv/` - Python virtual environment with Maestral (installed during postinst)
- `/usr/local/bin/maestral` - Symlink to Maestral command

## Maestral Dropbox Client

The package automatically installs [Maestral](https://maestral.app), an open-source Dropbox client for Linux, using pip in a dedicated virtual environment.

### Troubleshooting

If USB drives are not mounting automatically, use the included diagnostic script:

```bash
sudo diagnose-disks.sh
```

This will analyze your system and show:
- All block devices and their properties
- USB device detection status
- udev attributes for disk devices
- Removable drive status (must be `removable=1` for automount)
- Current mount points

### Using Maestral

After package installation, set up Dropbox sync:

```bash
# Link your Dropbox account
maestral auth link

# Start syncing
maestral start

# Check sync status
maestral status

# Stop syncing
maestral stop

# Get help
maestral --help
```

### Why Maestral?

- Lightweight alternative to official Dropbox client
- Works on ARM64 (Raspberry Pi)
- Lower memory usage
- Open source
- CLI-first design (perfect for headless systems)

## Building the Package

Packages are built automatically via GitHub Actions when a tag is created.

To trigger a release:
1. Create and push a tag: `git tag v0.1.0 && git push origin v0.1.0`
2. Go to GitHub Actions → Package and Release workflow
3. Run workflow manually with the tag reference

The workflow will:
- Build ARM64 Debian package
- Create a draft GitHub release
- Attach the `.deb` file to the release

## Manual Installation

After downloading the `.deb` file:

```bash
sudo dpkg -i usb-automount_*.deb
```

## Manual Removal

```bash
# Remove package but keep configuration
sudo apt-get remove usb-automount

# Remove package and all configuration
sudo apt-get purge usb-automount
```
