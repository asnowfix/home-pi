#!/bin/bash
set -e

MAESTRAL_VENV="/opt/maestral-venv"

# Common cleanup function
cleanup_maestral() {
    # Reload udev rules
    udevadm control --reload-rules
    udevadm trigger

    # Remove Maestral virtual environment
    if [ -d "$MAESTRAL_VENV" ]; then
        echo "Removing Maestral installation..."
        rm -rf "$MAESTRAL_VENV"
    fi

    # Remove Maestral symlink
    if [ -L /usr/local/bin/maestral ]; then
        rm -f /usr/local/bin/maestral
    fi
}

cleanup_rclone_services() {
    systemctl disable rclone-watch-gdrive.service 2>/dev/null || true
    systemctl disable rclone-pull-gdrive.timer 2>/dev/null || true
    rm -f /etc/systemd/system/rclone-watch-gdrive.service
    rm -f /etc/systemd/system/rclone-pull-gdrive.service
    rm -f /etc/systemd/system/rclone-pull-gdrive.timer
    systemctl daemon-reload
}

# Check if the script is being run during package purge (complete removal)
if [ "$1" = "purge" ]; then
    echo "Purging homepi-server configuration..."

    cleanup_maestral
    cleanup_rclone_services

    # Optionally remove Maestral config and cache (commented out for safety)
    # User data is typically in ~/.config/maestral and ~/.cache/maestral
    # rm -rf /root/.config/maestral /root/.cache/maestral

    # Optionally remove log file (commented out for safety)
    # rm -f /var/log/usb-automount.log
    # rm -f /var/log/rclone-sync.log
    # Note: /data/GoogleDrive and rclone.conf are preserved for safety

    echo "homepi-server has been purged."
fi

# On remove (not purge), reload udev rules
if [ "$1" = "remove" ]; then
    echo "Removing homepi-server..."

    cleanup_maestral
    cleanup_rclone_services

    echo "homepi-server has been removed."
    echo "Note: Maestral/rclone configuration and synced files are preserved."
fi

# Exit successfully
exit 0
