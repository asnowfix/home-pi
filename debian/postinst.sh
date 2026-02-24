#!/bin/bash
set -e

SERVICE="usb-automount"

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
    
    echo "USB automount installed successfully!"
    echo "USB devices will now automatically mount to /media/<label> when plugged in."
    echo "Check /var/log/usb-automount.log for mount/unmount activity."
fi

# Exit successfully
exit 0
