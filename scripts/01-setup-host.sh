#!/bin/bash
# Muslinx Linux Distribution — Host Setup Script
# Prepares the host build environment with required packages and variables

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MUSLINX_ROOT="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/helpers/common.env" 2>/dev/null || true

echo "═══════════════════════════════════════════"
echo "  Muslinx — Phase 1: Host Environment Setup"
echo "═══════════════════════════════════════════"

# Check for root/sudo
if [ "$EUID" -ne 0 ]; then
    SUDO="sudo"
else
    SUDO=""
fi

echo "[*] Installing host build dependencies..."
$SUDO apt update && $SUDO apt install -y \
    build-essential bison flex texinfo gawk curl wget \
    xz-utils python3 perl m4 patch file bc cpio \
    libssl-dev libelf-dev grub-pc-bin grub-efi-amd64-bin \
    xorriso mtools dosfstools squashfs-tools \
    qemu-system-x86 ovmf git autoconf automake libtool \
    pkg-config cmake meson ninja-build gettext

echo "[*] Setting up build environment variables..."

# Export build variables
export MUSLINX_ROOT
export MUSLINX_TARGET="x86_64-muslinx-linux-musl"
export MUSLINX_TOOLCHAIN="$MUSLINX_ROOT/toolchain"
export MUSLINX_SYSROOT="$MUSLINX_ROOT/rootfs"
export MUSLINX_SOURCES="$MUSLINX_ROOT/sources"
export MAKEFLAGS="-j$(nproc)"

# Create source download directory
mkdir -pv "$MUSLINX_SOURCES"
mkdir -pv "$MUSLINX_TOOLCHAIN"

# Write environment file for other scripts to source
cat > "$SCRIPT_DIR/helpers/common.env" << EOF
export MUSLINX_ROOT="$MUSLINX_ROOT"
export MUSLINX_TARGET="x86_64-muslinx-linux-musl"
export MUSLINX_TOOLCHAIN="$MUSLINX_ROOT/toolchain"
export MUSLINX_SYSROOT="$MUSLINX_ROOT/rootfs"
export MUSLINX_SOURCES="$MUSLINX_ROOT/sources"
export PATH="$MUSLINX_TOOLCHAIN/bin:\$PATH"
export MAKEFLAGS="-j\$(nproc)"

# Package versions
export LINUX_VERSION="6.6.70"
export MUSL_VERSION="1.2.5"
export BINUTILS_VERSION="2.42"
export GCC_VERSION="14.2.0"
export BUSYBOX_VERSION="1.36.1"
export ZLIB_VERSION="1.3.1"
export XZ_VERSION="5.6.3"
export ZSTD_VERSION="1.5.6"
export BZIP2_VERSION="1.0.8"
export NCURSES_VERSION="6.5"
export READLINE_VERSION="8.2"
export BASH_VERSION_PKG="5.2.37"
export COREUTILS_VERSION="9.5"
export UTIL_LINUX_VERSION="2.40.2"
export E2FSPROGS_VERSION="1.47.1"
export SHADOW_VERSION="4.16.0"
export OPENSSH_VERSION="9.9p1"
export CURL_VERSION="8.11.1"
export LIBRESSL_VERSION="4.0.0"
export IPROUTE2_VERSION="6.11.0"
export DHCPCD_VERSION="10.1.0"
export SWAY_VERSION="1.10"
export WLROOTS_VERSION="0.18.2"
export WAYBAR_VERSION="0.11.0"
export FOOT_VERSION="1.19.0"
export ZSH_VERSION_PKG="5.9"
export SKALIBS_VERSION="2.14.3.0"
export EXECLINE_VERSION="2.9.6.1"
export S6_VERSION="2.13.1.0"
export S6_LINUX_INIT_VERSION="1.1.2.0"
export S6_RC_VERSION="0.5.4.2"
export EUDEV_VERSION="3.2.14"
export KMOD_VERSION="33"
export GRUB_VERSION="2.12"
EOF

echo "[*] Environment file written to $SCRIPT_DIR/helpers/common.env"
echo ""
echo "[✓] Host setup complete!"
echo "    Source the environment before running other scripts:"
echo "    source $SCRIPT_DIR/helpers/common.env"
