#!/bin/bash
# Muslinx — Chroot Helper
# Executes commands inside the Muslinx sysroot chroot
# Usage: chroot-run.sh <command> [args...]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.env"

SYSROOT="$MUSLINX_SYSROOT"

if [ $# -eq 0 ]; then
    echo "Usage: $0 <command> [args...]"
    echo "       $0 --interactive  (for interactive shell)"
    exit 1
fi

# Mount virtual filesystems
mount_vfs() {
    echo "[*] Mounting virtual filesystems in chroot..."
    mount --bind /dev "$SYSROOT/dev" 2>/dev/null || true
    mount -t devpts devpts "$SYSROOT/dev/pts" -o gid=5,mode=620 2>/dev/null || true
    mount -t proc proc "$SYSROOT/proc" 2>/dev/null || true
    mount -t sysfs sysfs "$SYSROOT/sys" 2>/dev/null || true
    mount -t tmpfs tmpfs "$SYSROOT/run" 2>/dev/null || true
    mount -t tmpfs tmpfs "$SYSROOT/tmp" 2>/dev/null || true

    # Copy DNS config for network access
    cp -L /etc/resolv.conf "$SYSROOT/etc/resolv.conf" 2>/dev/null || true
}

# Unmount virtual filesystems
umount_vfs() {
    echo "[*] Unmounting virtual filesystems..."
    umount "$SYSROOT/tmp" 2>/dev/null || true
    umount "$SYSROOT/run" 2>/dev/null || true
    umount "$SYSROOT/sys" 2>/dev/null || true
    umount "$SYSROOT/proc" 2>/dev/null || true
    umount "$SYSROOT/dev/pts" 2>/dev/null || true
    umount "$SYSROOT/dev" 2>/dev/null || true
}

# Cleanup on exit
trap umount_vfs EXIT

mount_vfs

if [ "$1" = "--interactive" ]; then
    echo "[*] Entering Muslinx chroot (type 'exit' to leave)..."
    chroot "$SYSROOT" /bin/bash -l
else
    echo "[*] Running in chroot: $*"
    chroot "$SYSROOT" /bin/bash -c "$*"
fi
