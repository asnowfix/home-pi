#!/bin/bash

# Log file for debugging
LOG="/var/log/usb-automount.log"

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "${LOG}"
}

# Validate input parameters
if [ -z "$1" ] || [ -z "$2" ]; then
    log_msg "ERROR: Missing required parameters (action: '$1', device: '$2')"
    exit 1
fi

ACTION=$1
DEVBASE=$2
DEVICE="/dev/${DEVBASE}"

# See if this drive is already mounted
MOUNT_POINT=$(/bin/mount | /bin/grep "${DEVICE}" | /usr/bin/awk '{ print $3 }')

do_mount() {
    if [[ -n ${MOUNT_POINT} ]]; then
        log_msg "${DEVICE} already mounted at ${MOUNT_POINT}"
        exit 1
    fi

    # Get the filesystem label
    LABEL=$(/sbin/blkid -s LABEL -o value "${DEVICE}")
    [ -z "${LABEL}" ] && LABEL="${DEVBASE}"

    # Create mount point with device name to avoid conflicts with duplicate labels
    MOUNT_POINT="/media/${LABEL}-${DEVBASE}"
    /bin/mkdir -p "${MOUNT_POINT}"

    # Mount the device with appropriate options
    # umask=000 gives full permissions, works for FAT/NTFS
    # For ext4, we'll add uid/gid options
    FSTYPE=$(/sbin/blkid -s TYPE -o value "${DEVICE}")
    
    if [[ "${FSTYPE}" == "vfat" ]] || [[ "${FSTYPE}" == "ntfs" ]] || [[ "${FSTYPE}" == "exfat" ]]; then
        /bin/mount -o rw,users,umask=000 "${DEVICE}" "${MOUNT_POINT}"
    else
        /bin/mount -o rw,users "${DEVICE}" "${MOUNT_POINT}"
    fi

    if [ $? -eq 0 ]; then
        log_msg "Mounted ${DEVICE} (${FSTYPE}) at ${MOUNT_POINT}"
    else
        log_msg "Failed to mount ${DEVICE}"
        if /bin/rmdir "${MOUNT_POINT}" 2>/dev/null; then
            log_msg "Removed empty mount point ${MOUNT_POINT}"
        else
            log_msg "Could not remove mount point ${MOUNT_POINT} (may not be empty or already removed)"
        fi
    fi
}

do_unmount() {
    if [[ -z ${MOUNT_POINT} ]]; then
        log_msg "${DEVICE} not mounted"
        exit 0
    fi

    /bin/umount -l "${DEVICE}"
    
    if [ $? -eq 0 ]; then
        log_msg "Unmounted ${DEVICE} from ${MOUNT_POINT}"
        # Remove mount point if empty
        if /bin/rmdir "${MOUNT_POINT}" 2>/dev/null; then
            log_msg "Removed mount point ${MOUNT_POINT}"
        else
            log_msg "Could not remove mount point ${MOUNT_POINT} (may not be empty)"
        fi
    else
        log_msg "Failed to unmount ${DEVICE}"
    fi
}

case "${ACTION}" in
    add)
        log_msg "USB device added: ${DEVICE}"
        do_mount
        ;;
    remove)
        log_msg "USB device removed: ${DEVICE}"
        do_unmount
        ;;
esac
