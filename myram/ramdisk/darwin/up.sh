#!/usr/bin/env bash

# This program has two feature.
#
# 1. Create a disk image on RAM.
# 2. Mount that disk image.
#
# Usage:
#   $0 <dir> <size>
#
#   size:
#     The `size' is a size of disk image (MB).
#
#   dir:
#     The `dir' is a directory, the dir is used to mount the disk image.
#
# See also:
#   - hdid(8)
#

mount_point=${1}
size=${2:-256}

mkdir -p ${mount_point}
if [ $? -ne 0 ]; then
    echo "The mount point didn't available." >&2
    exit $?
fi
chmod 777 ${mount_point}

sectors=$((${size}*1024*1024/512))
device_name=$(hdid -nomount "ram://${sectors}" | awk '{print $1}')
if [ $? -ne 0 ]; then
    echo "Could not create disk image." >&2
    exit $?
fi

newfs_hfs -v 'ramdisk' ${device_name} > /dev/null
if [ $? -ne 0 ]; then
    echo "Could not format disk image." >&2
    exit $?
fi

mount -v -o noatime -o nobrowse -t hfs ${device_name} ${mount_point}
if [ $? -ne 0 ]; then
    echo "Could not mount disk image." >&2
    exit $?
fi
