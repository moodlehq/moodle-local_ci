#!/usr/bin/env bash -e

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
size=${2:-64}

mkdir -p $mount_point
if [ $? -ne 0 ]; then
    echo "The mount point didn't available." >&2
    exit $?
fi

mount -t tmpfs -o size=${size}M tmpfs ${mount_point}
if [ $? -ne 0 ]; then
    echo "Could not create disk image." >&2
    exit $?
fi
