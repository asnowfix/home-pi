#!/bin/bash
set -e

# Check if the script is being run during package purge (complete removal)
if [ "$1" = "purge" ]; then
    echo "Purging USB automount configuration..."
    
    # Reload udev rules to remove our custom rule
    udevadm control --reload-rules
    udevadm trigger
    
    # Optionally remove log file (commented out for safety)
    # rm -f /var/log/usb-automount.log
    
    echo "USB automount has been purged."
fi

# On remove (not purge), reload udev rules
if [ "$1" = "remove" ]; then
    echo "Removing USB automount..."
    
    # Reload udev rules
    udevadm control --reload-rules
    udevadm trigger
    
    echo "USB automount has been removed."
fi

# Exit successfully
exit 0
