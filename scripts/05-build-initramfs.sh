#!/bin/bash
# Muslinx Linux Distribution — Initramfs Build
# Creates the initial ramdisk for early boot

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers/common.env"

echo "═══════════════════════════════════════════"
echo "  Muslinx — Phase 4: Build Initramfs"
echo "═══════════════════════════════════════════"

FETCH="$SCRIPT_DIR/helpers/fetch-source.sh"
BUILD_DIR="$MUSLINX_ROOT/build"
INITRAMFS_DIR="$BUILD_DIR/initramfs"

# Clean and create initramfs structure
rm -rf "$INITRAMFS_DIR"
mkdir -p "$INITRAMFS_DIR"/{bin,dev,etc,lib,proc,sys,mnt/{root,cdrom},run,tmp}

# ──────────────────────────────────────────────
# Build static BusyBox for initramfs
# ──────────────────────────────────────────────
echo "[*] Building static BusyBox for initramfs..."
$FETCH "https://busybox.net/downloads/busybox-$BUSYBOX_VERSION.tar.bz2" \
    "$MUSLINX_SOURCES/busybox-$BUSYBOX_VERSION.tar.bz2"

cd "$BUILD_DIR"
rm -rf "busybox-$BUSYBOX_VERSION"
tar xf "$MUSLINX_SOURCES/busybox-$BUSYBOX_VERSION.tar.bz2"
cd "busybox-$BUSYBOX_VERSION"

make defconfig
# Enable static build
sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
# Set cross-compiler
sed -i "s|CONFIG_CROSS_COMPILER_PREFIX=\"\"|CONFIG_CROSS_COMPILER_PREFIX=\"${MUSLINX_TARGET}-\"|" .config

make $MAKEFLAGS
cp busybox "$INITRAMFS_DIR/bin/busybox"

# Create busybox symlinks
for applet in sh mount umount switch_root mkdir cat echo sleep; do
    ln -sf busybox "$INITRAMFS_DIR/bin/$applet"
done

# ──────────────────────────────────────────────
# Create init script
# ──────────────────────────────────────────────
echo "[*] Creating init script..."
cat > "$INITRAMFS_DIR/init" << 'INITEOF'
#!/bin/sh
# Muslinx Initramfs Init Script

# Mount virtual filesystems
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs dev /dev

echo ""
echo "  ✦ Muslinx Linux — Early Boot"
echo ""

# Parse kernel command line
ROOT=""
for param in $(cat /proc/cmdline); do
    case "$param" in
        root=*) ROOT="${param#root=}" ;;
    esac
done

if [ -z "$ROOT" ]; then
    # ── Live ISO Mode ──
    echo "[initramfs] Live mode detected, mounting squashfs..."
    mkdir -p /mnt/cdrom /mnt/root/lower /mnt/root/upper /mnt/root/work /mnt/root/merged

    # Try to find and mount the ISO media
    for dev in /dev/sr0 /dev/sr1 /dev/vda /dev/sda; do
        if [ -b "$dev" ]; then
            mount -o ro "$dev" /mnt/cdrom 2>/dev/null && break
        fi
    done

    if [ -f /mnt/cdrom/muslinx.squashfs ]; then
        mount -t squashfs -o loop /mnt/cdrom/muslinx.squashfs /mnt/root/lower
        mount -t tmpfs tmpfs /mnt/root/upper
        mkdir -p /mnt/root/upper/upper /mnt/root/upper/work
        mount -t overlay overlay \
            -o lowerdir=/mnt/root/lower,upperdir=/mnt/root/upper/upper,workdir=/mnt/root/upper/work \
            /mnt/root/merged
        echo "[initramfs] OverlayFS mounted, switching root..."
        exec switch_root /mnt/root/merged /sbin/init
    else
        echo "[initramfs] ERROR: muslinx.squashfs not found!"
        exec sh
    fi
else
    # ── Installed Mode ──
    echo "[initramfs] Installed mode, mounting root=$ROOT..."
    mount "$ROOT" /mnt/root
    if [ -x /mnt/root/sbin/init ]; then
        exec switch_root /mnt/root /sbin/init
    else
        echo "[initramfs] ERROR: /sbin/init not found on $ROOT!"
        exec sh
    fi
fi

echo "[initramfs] Boot failed! Dropping to emergency shell."
exec sh
INITEOF
chmod +x "$INITRAMFS_DIR/init"

# ──────────────────────────────────────────────
# Package initramfs
# ──────────────────────────────────────────────
echo "[*] Packaging initramfs..."
cd "$INITRAMFS_DIR"
find . | cpio -o -H newc 2>/dev/null | gzip > "$MUSLINX_SYSROOT/boot/initramfs-muslinx.img"

echo ""
echo "═══════════════════════════════════════════"
echo "  Initramfs build complete!"
echo "  Image: $MUSLINX_SYSROOT/boot/initramfs-muslinx.img"
echo "═══════════════════════════════════════════"
