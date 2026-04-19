#!/bin/bash
set -e

MAESTRAL_VENV="/opt/maestral-venv"
RCLONE_USER="${SUDO_USER:-$(getent passwd 1000 | cut -d: -f1)}"
GDRIVE_LOCAL="/data/GoogleDrive"
RCLONE_MIN_VERSION="1.65"

# Create log file with appropriate permissions
touch /var/log/usb-automount.log
chmod 644 /var/log/usb-automount.log

# Create /media directory if it doesn't exist
mkdir -p /media

# Check if the script is being run during package installation
if [ "$1" = "configure" ]; then
    # Reload udev rules
    echo "Reloading udev rules..."
    udevadm control --reload-rules
    udevadm trigger

    echo "homepi-server: USB automount configured."
    echo "USB devices will now automatically mount to /media/<label> when plugged in."
    echo "Check /var/log/usb-automount.log for mount/unmount activity."

    # Install Maestral Dropbox client
    echo ""
    echo "Installing Maestral Dropbox client..."

    # Create virtual environment for Maestral
    if [ ! -d "$MAESTRAL_VENV" ]; then
        echo "Creating Python virtual environment at $MAESTRAL_VENV..."
        python3 -m venv "$MAESTRAL_VENV"
    fi

    # Install/upgrade Maestral (without GUI to avoid PyQt6 build issues on Pi)
    echo "Installing Maestral package..."
    if ! "$MAESTRAL_VENV/bin/python3" -m pip install --upgrade pip; then
        echo "ERROR: Failed to upgrade pip" >&2
        exit 1
    fi

    if ! "$MAESTRAL_VENV/bin/python3" -m pip install --upgrade maestral; then
        echo "ERROR: Failed to install Maestral" >&2
        exit 1
    fi

    # Create symlink to make maestral command available system-wide
    if [ -e /usr/local/bin/maestral ] && [ ! -L /usr/local/bin/maestral ]; then
        echo "WARNING: /usr/local/bin/maestral exists and is not a symlink" >&2
        echo "WARNING: It will be replaced with a symlink to the packaged version" >&2
    fi
    ln -sf "$MAESTRAL_VENV/bin/maestral" /usr/local/bin/maestral

    echo ""
    echo "Maestral installed successfully!"
    echo "To set up Dropbox sync, run: maestral auth link"
    echo "To start syncing: maestral start"

    # Install inotify-tools
    echo ""
    echo "Installing inotify-tools..."
    apt-get install -y inotify-tools

    # Install rclone: try apt if version >= 1.65, otherwise use official installer
    echo "Installing rclone..."
    RCLONE_APT_VERSION=$(apt-cache policy rclone 2>/dev/null | grep 'Candidate:' | awk '{print $2}' | cut -d'-' -f1 | cut -d':' -f2)
    if [ -n "$RCLONE_APT_VERSION" ] && dpkg --compare-versions "$RCLONE_APT_VERSION" ge "$RCLONE_MIN_VERSION"; then
        echo "apt rclone $RCLONE_APT_VERSION >= $RCLONE_MIN_VERSION, installing from apt..."
        apt-get install -y rclone
    else
        echo "apt rclone version too old or unavailable, installing from official installer..."
        curl https://rclone.org/install.sh | bash
    fi

    # Raise inotify watch limit
    if ! grep -q "fs.inotify.max_user_watches" /etc/sysctl.conf; then
        echo "fs.inotify.max_user_watches=524288" >> /etc/sysctl.conf
        sysctl -p
    fi

    # Create sync directory and log file
    mkdir -p "$GDRIVE_LOCAL"
    chown "${RCLONE_USER}:${RCLONE_USER}" "$GDRIVE_LOCAL"
    touch /var/log/rclone-sync.log
    chmod 644 /var/log/rclone-sync.log

    # Substitute user placeholder in shipped service files and enable (do not start)
    sed -i "s/@@RCLONE_USER@@/${RCLONE_USER}/g" /etc/systemd/system/rclone-watch-gdrive.service
    sed -i "s/@@RCLONE_USER@@/${RCLONE_USER}/g" /etc/systemd/system/rclone-pull-gdrive.service
    systemctl daemon-reload
    systemctl enable rclone-watch-gdrive.service
    systemctl enable rclone-pull-gdrive.timer

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " Google Drive sync is installed but NOT yet started."
    echo " This Pi has no browser — authentication is done via another"
    echo " device. Run the setup wizard to complete configuration:"
    echo ""
    echo "   sudo homepi-gdrive-setup"
    echo ""
    echo " Safe to re-run at any time if something goes wrong."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

# Exit successfully
exit 0
