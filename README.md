# home-pi

Utilities and scripts for Rapsberry PI @ Home

## USB Automount

USB automount script for headless Raspberry Pi

### Installation

```bash
sudo ./install-usb-automount.sh
```

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
