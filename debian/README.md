# Debian Package Maintainer Scripts

This directory contains the maintainer scripts used during Debian package installation, upgrade, and removal.

## Files

- **postinst.sh** - Post-installation script
  - Creates log file `/var/log/usb-automount.log`
  - Creates `/media` directory
  - Reloads udev rules to activate USB automount

- **prerm.sh** - Pre-removal script
  - Runs before package removal or upgrade
  - Currently informational only

- **postrm.sh** - Post-removal script
  - Reloads udev rules after removal
  - On purge, can optionally remove log files

## Package Structure

The Debian package installs:
- `/usr/local/bin/usb-automount.sh` - Main automount script
- `/etc/udev/rules.d/99-usb-automount.rules` - Udev rule for USB device detection

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
