#!/bin/bash

# Installation script for USB automount on headless Raspberry Pi

set -e

echo "Installing USB automount for Raspberry Pi..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Check if usbmount is installed
if dpkg -l | grep -q "^ii  usbmount"; then
    echo "ERROR: usbmount package is installed!"
    echo "This script conflicts with usbmount. Please remove it first:"
    echo "  sudo apt-get remove usbmount"
    exit 1
fi

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Copy the automount script
echo "Installing automount script..."
cp "${SCRIPT_DIR}/usb-automount.sh" /usr/local/bin/usb-automount.sh
chmod +x /usr/local/bin/usb-automount.sh

# Copy the udev rule
echo "Installing udev rule..."
cp "${SCRIPT_DIR}/99-usb-automount.rules" /etc/udev/rules.d/99-usb-automount.rules

# Create log file with appropriate permissions
echo "Creating log file..."
touch /var/log/usb-automount.log
chmod 644 /var/log/usb-automount.log

# Create /media directory if it doesn't exist
mkdir -p /media

# Reload udev rules
echo "Reloading udev rules..."
udevadm control --reload-rules
udevadm trigger

echo ""
echo "Installation complete!"
echo ""
echo "USB devices will now automatically mount to /media/<label> when plugged in."
echo "Check /var/log/usb-automount.log for mount/unmount activity."
echo ""
echo "To test: plug in a USB drive and check 'ls /media/'"
