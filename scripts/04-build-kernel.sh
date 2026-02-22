#!/bin/bash
# Muslinx Linux Distribution — Kernel Build
# Compiles the Linux kernel with Muslinx configuration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers/common.env"

echo "═══════════════════════════════════════════"
echo "  Muslinx — Phase 4: Build Linux Kernel"
echo "═══════════════════════════════════════════"

FETCH="$SCRIPT_DIR/helpers/fetch-source.sh"
BUILD_DIR="$MUSLINX_ROOT/build"
CONFIGS_DIR="$MUSLINX_ROOT/configs"

# Download kernel if not already present
$FETCH "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$LINUX_VERSION.tar.xz" \
    "$MUSLINX_SOURCES/linux-$LINUX_VERSION.tar.xz"

cd "$BUILD_DIR"
[ -d "linux-$LINUX_VERSION" ] || tar xf "$MUSLINX_SOURCES/linux-$LINUX_VERSION.tar.xz"
cd "linux-$LINUX_VERSION"

echo "[*] Cleaning kernel tree..."
make mrproper

# Use Muslinx kernel config if available, otherwise start from defconfig
if [ -f "$CONFIGS_DIR/kernel.config" ]; then
    echo "[*] Using Muslinx kernel configuration..."
    cp "$CONFIGS_DIR/kernel.config" .config
else
    echo "[*] Generating default config and applying Muslinx settings..."
    make ARCH=x86_64 defconfig

    # Apply Muslinx-specific kernel options
    scripts/config --enable CONFIG_IKCONFIG
    scripts/config --enable CONFIG_IKCONFIG_PROC
    scripts/config --enable CONFIG_EFI
    scripts/config --enable CONFIG_EFI_STUB

    # Filesystems
    scripts/config --enable CONFIG_SQUASHFS
    scripts/config --enable CONFIG_SQUASHFS_XZ
    scripts/config --enable CONFIG_SQUASHFS_ZSTD
    scripts/config --enable CONFIG_OVERLAY_FS
    scripts/config --enable CONFIG_EXT4_FS
    scripts/config --enable CONFIG_VFAT_FS
    scripts/config --enable CONFIG_TMPFS
    scripts/config --enable CONFIG_FUSE_FS

    # Graphics/DRM
    scripts/config --enable CONFIG_DRM
    scripts/config --enable CONFIG_DRM_KMS_HELPER
    scripts/config --enable CONFIG_DRM_VIRTIO_GPU
    scripts/config --enable CONFIG_DRM_BOCHS
    scripts/config --enable CONFIG_DRM_I915
    scripts/config --enable CONFIG_DRM_AMDGPU
    scripts/config --enable CONFIG_DRM_NOUVEAU
    scripts/config --enable CONFIG_FB_VESA

    # Input
    scripts/config --enable CONFIG_INPUT_EVDEV
    scripts/config --enable CONFIG_USB_HID

    # VirtIO (for VM testing)
    scripts/config --enable CONFIG_VIRTIO_PCI
    scripts/config --enable CONFIG_VIRTIO_NET
    scripts/config --enable CONFIG_VIRTIO_BLK
    scripts/config --enable CONFIG_VIRTIO_CONSOLE
    scripts/config --enable CONFIG_SCSI_VIRTIO

    # Audio
    scripts/config --enable CONFIG_SND_HDA_INTEL

    # Device management
    scripts/config --enable CONFIG_DEVTMPFS
    scripts/config --enable CONFIG_DEVTMPFS_MOUNT
    scripts/config --enable CONFIG_INOTIFY_USER

    # Save config for future builds
    cp .config "$CONFIGS_DIR/kernel.config"
fi

echo "[*] Building kernel..."
make ARCH=x86_64 $MAKEFLAGS

echo "[*] Installing kernel..."
mkdir -p "$MUSLINX_SYSROOT/boot"
cp arch/x86_64/boot/bzImage "$MUSLINX_SYSROOT/boot/vmlinuz-muslinx"

echo "[*] Installing modules..."
make modules_install INSTALL_MOD_PATH="$MUSLINX_SYSROOT"

echo ""
echo "═══════════════════════════════════════════"
echo "  Kernel build complete!"
echo "  Image: $MUSLINX_SYSROOT/boot/vmlinuz-muslinx"
echo "═══════════════════════════════════════════"
