#!/bin/bash
set -e

MAESTRAL_VENV="/opt/maestral-venv"

# Check if the script is being run during package removal
if [ "$1" = "remove" ] || [ "$1" = "upgrade" ]; then
    echo "Preparing to remove homepi-server..."

    # Stop Maestral if it's running
    if [ -f "$MAESTRAL_VENV/bin/maestral" ]; then
        echo "Stopping Maestral daemon..."
        "$MAESTRAL_VENV/bin/maestral" stop 2>/dev/null || true
    fi

    # Stop rclone sync services
    echo "Stopping rclone sync services..."
    systemctl stop rclone-watch-gdrive.service 2>/dev/null || true
    systemctl stop rclone-pull-gdrive.timer 2>/dev/null || true
    systemctl stop rclone-pull-gdrive.service 2>/dev/null || true
fi

# Exit successfully
exit 0
