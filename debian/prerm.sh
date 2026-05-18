#!/bin/bash
set -e

MAESTRAL_VENV="/opt/maestral-venv"

# Check if the script is being run during package removal
if [ "$1" = "remove" ] || [ "$1" = "upgrade" ]; then
    echo "Preparing to remove homepi-server..."


    # Stop Maestral systemd services for all whitelisted users
    MAESTRAL_USERS="/etc/homepi/maestral-users"
    if [ -f "$MAESTRAL_USERS" ]; then
        while IFS= read -r user || [ -n "$user" ]; do
            user=$(echo "$user" | sed 's/#.*//' | xargs)
            [ -z "$user" ] && continue
            if systemctl is-active --quiet "maestral@${user}.service" 2>/dev/null; then
                echo "Stopping maestral@${user}.service..."
                systemctl stop "maestral@${user}.service" || true
            fi
            systemctl disable "maestral@${user}.service" 2>/dev/null || true
        done < "$MAESTRAL_USERS"
    fi

    # Also stop any manually-started Maestral daemon
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
