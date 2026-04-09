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

# Check if the script is being run during package purge (complete removal)
if [ "$1" = "purge" ]; then
    echo "Purging homepi-server configuration..."
    
    cleanup_maestral
    
    # Optionally remove Maestral config and cache (commented out for safety)
    # User data is typically in ~/.config/maestral and ~/.cache/maestral
    # rm -rf /root/.config/maestral /root/.cache/maestral
    
    # Optionally remove log file (commented out for safety)
    # rm -f /var/log/usb-automount.log
    
    echo "homepi-server has been purged."
fi

# On remove (not purge), reload udev rules
if [ "$1" = "remove" ]; then
    echo "Removing homepi-server..."
    
    cleanup_maestral
    
    echo "homepi-server has been removed."
    echo "Note: Maestral configuration and synced files are preserved."
fi

# Exit successfully
exit 0
