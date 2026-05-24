#!/bin/bash

# Log file for debugging
LOG="/var/log/usb-automount.log"

log_msg() {
    local msg="$(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo "${msg}" >> "${LOG}"
    echo "${msg}" >&2
}

# Validate input parameters
if [ -z "$1" ] || [ -z "$2" ]; then
    log_msg "ERROR: Missing required parameters (action: '$1', device: '$2')"
    exit 1
fi

ACTION=$1
DEVBASE=$2
DEVICE="/dev/${DEVBASE}"

# Skip whole-disk devices that have partitions (mount the partitions instead)
if [[ "${DEVBASE}" =~ ^sd[a-z]$ ]] && ls /dev/${DEVBASE}[0-9]* &>/dev/null; then
    log_msg "Skipping ${DEVICE} — has partitions, will mount those instead"
    exit 0
fi

# See if this drive is already mounted
MOUNT_POINT=$(mount | grep "${DEVICE}" | awk '{ print $3 }')

add_fstab_entry() {
    local uuid="$1" mount="$2" fstype="$3" opts="$4"
    # Avoid duplicates
    if grep -q "^UUID=${uuid} " /etc/fstab 2>/dev/null; then
        log_msg "fstab entry for UUID=${uuid} already exists"
        return
    fi
    echo "UUID=${uuid} ${mount} ${fstype} ${opts},nofail 0 2" >> /etc/fstab
    log_msg "Added fstab entry: UUID=${uuid} ${mount} ${fstype} ${opts},nofail"
}

remove_fstab_entry() {
    local uuid="$1"
    if [ -z "${uuid}" ]; then
        return
    fi
    if grep -q "^UUID=${uuid} " /etc/fstab 2>/dev/null; then
        sed -i "\|^UUID=${uuid} |d" /etc/fstab
        log_msg "Removed fstab entry for UUID=${uuid}"
    fi
}

do_mount() {
    if [[ -n ${MOUNT_POINT} ]]; then
        log_msg "${DEVICE} already mounted at ${MOUNT_POINT}"
        exit 1
    fi

    # Get the filesystem label
    LABEL=$(blkid -s LABEL -o value "${DEVICE}" 2>&1)
    if [ -z "${LABEL}" ]; then
        log_msg "No label found for ${DEVICE}, using device name"
        MOUNT_POINT="/media/${DEVBASE}"
    else
        log_msg "Label for ${DEVICE}: ${LABEL}"
        # Append device name to avoid conflicts when multiple devices share the same label
        MOUNT_POINT="/media/${LABEL}-${DEVBASE}"
    fi
    log_msg "Creating mount point ${MOUNT_POINT}"
    mkdir -p "${MOUNT_POINT}"

    # Mount the device with appropriate options
    # umask=000 gives full permissions, works for FAT/NTFS
    # For ext4, we'll add uid/gid options
    FSTYPE=$(blkid -s TYPE -o value "${DEVICE}" 2>&1)
    log_msg "Detected filesystem type: ${FSTYPE:-unknown}"

    if [[ "${FSTYPE}" == "vfat" ]] || [[ "${FSTYPE}" == "ntfs" ]] || [[ "${FSTYPE}" == "exfat" ]]; then
        MOUNT_OPTS="rw,users,umask=000"
        log_msg "Mounting ${DEVICE} with umask=000 (fat/ntfs/exfat)"
    else
        MOUNT_OPTS="rw,users"
        log_msg "Mounting ${DEVICE} with default options"
    fi
    MOUNT_OUT=$(mount -o "${MOUNT_OPTS}" "${DEVICE}" "${MOUNT_POINT}" 2>&1)

    if [ $? -eq 0 ]; then
        log_msg "Mounted ${DEVICE} (${FSTYPE}) at ${MOUNT_POINT}"
        UUID=$(blkid -s UUID -o value "${DEVICE}")
        if [ -n "${UUID}" ]; then
            add_fstab_entry "${UUID}" "${MOUNT_POINT}" "${FSTYPE}" "${MOUNT_OPTS}"
        else
            log_msg "WARNING: No UUID for ${DEVICE}, mount will not persist across reboots"
        fi
    else
        log_msg "Failed to mount ${DEVICE}: ${MOUNT_OUT}"
        if rmdir "${MOUNT_POINT}" 2>/dev/null; then
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

    UUID=$(blkid -s UUID -o value "${DEVICE}" 2>/dev/null)
    UMOUNT_OUT=$(umount -l "${DEVICE}" 2>&1)

    if [ $? -eq 0 ]; then
        log_msg "Unmounted ${DEVICE} from ${MOUNT_POINT}"
        remove_fstab_entry "${UUID}"
        # Remove mount point if empty
        if rmdir "${MOUNT_POINT}" 2>/dev/null; then
            log_msg "Removed mount point ${MOUNT_POINT}"
        else
            log_msg "Could not remove mount point ${MOUNT_POINT} (may not be empty)"
        fi
    else
        log_msg "Failed to unmount ${DEVICE}: ${UMOUNT_OUT}"
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
