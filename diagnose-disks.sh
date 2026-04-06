#!/bin/bash
# Diagnostic script to analyze disk configuration on Raspberry Pi
# Run this on your target device to help determine the best udev filter

echo "=== All block devices ==="
lsblk -o NAME,TYPE,SIZE,MOUNTPOINT,HOTPLUG,RM,TRAN

echo -e "\n=== USB devices only ==="
lsblk -o NAME,TYPE,SIZE,MOUNTPOINT,HOTPLUG,RM,TRAN | grep -E "(usb|^NAME)"

echo -e "\n=== Detailed udev attributes for all sd devices ==="
for dev in /dev/sd?; do
    if [ -b "$dev" ]; then
        echo "--- $dev ---"
        udevadm info --query=property --name=$dev | grep -E "(DEVNAME|ID_BUS|SUBSYSTEM|ID_USB|ATTR.*removable)"
    fi
done

echo -e "\n=== Check removable attribute ==="
for dev in /sys/block/sd?; do
    if [ -e "$dev/removable" ]; then
        echo "$(basename $dev): removable=$(cat $dev/removable)"
    fi
done

echo -e "\n=== Current mount points ==="
mount | grep "^/dev/sd"

echo -e "\n=== Test udev rule matching (requires a USB drive to be connected) ==="
echo "Plug in a USB drive and run: udevadm test /sys/block/sdX"
