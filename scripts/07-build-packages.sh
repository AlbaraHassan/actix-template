#!/bin/bash
# Muslinx Linux Distribution — Additional Userland Packages
# Builds supplementary packages for a complete desktop experience

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers/common.env"

echo "═══════════════════════════════════════════"
echo "  Muslinx — Phase 5: Build Userland Packages"
echo "═══════════════════════════════════════════"

FETCH="$SCRIPT_DIR/helpers/fetch-source.sh"
BUILD_DIR="$MUSLINX_ROOT/build"
mkdir -p "$BUILD_DIR"

export CC="${MUSLINX_TARGET}-gcc"
export CXX="${MUSLINX_TARGET}-g++"
export PKG_CONFIG_PATH="$MUSLINX_SYSROOT/usr/lib/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="$MUSLINX_SYSROOT"

build_package() {
    local name="$1"
    local version="$2"
    local url="$3"
    local ext="${4:-.tar.xz}"
    local configure_flags="${5:-}"

    echo ""
    echo "──── Building: $name $version ────"

    $FETCH "$url" "$MUSLINX_SOURCES/${name}-${version}${ext}"

    cd "$BUILD_DIR"
    rm -rf "${name}-${version}"
    tar xf "$MUSLINX_SOURCES/${name}-${version}${ext}"
    cd "${name}-${version}"

    if [ -f configure ]; then
        ./configure \
            --host="$MUSLINX_TARGET" \
            --prefix=/usr \
            --sysconfdir=/etc \
            $configure_flags
        make $MAKEFLAGS
        make install DESTDIR="$MUSLINX_SYSROOT"
    elif [ -f CMakeLists.txt ]; then
        mkdir -p build && cd build
        cmake .. \
            -DCMAKE_INSTALL_PREFIX=/usr \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_COMPILER="$CC" \
            -DCMAKE_CXX_COMPILER="$CXX"
        make $MAKEFLAGS
        make install DESTDIR="$MUSLINX_SYSROOT"
    fi
    echo "[✓] $name $version installed"
}

# ──────────────────────────────────────────────
# s6 init system stack
# ──────────────────────────────────────────────
echo "[*] Building s6 init system..."

for s6_pkg in \
    "skalibs:$SKALIBS_VERSION:https://skarnet.org/software/skalibs/skalibs-$SKALIBS_VERSION.tar.gz" \
    "execline:$EXECLINE_VERSION:https://skarnet.org/software/execline/execline-$EXECLINE_VERSION.tar.gz" \
    "s6:$S6_VERSION:https://skarnet.org/software/s6/s6-$S6_VERSION.tar.gz" \
    "s6-linux-init:$S6_LINUX_INIT_VERSION:https://skarnet.org/software/s6-linux-init/s6-linux-init-$S6_LINUX_INIT_VERSION.tar.gz" \
    "s6-rc:$S6_RC_VERSION:https://skarnet.org/software/s6-rc/s6-rc-$S6_RC_VERSION.tar.gz"; do

    IFS=: read -r name version url <<< "$s6_pkg"
    echo ""
    echo "──── Building: $name $version ────"

    $FETCH "$url" "$MUSLINX_SOURCES/${name}-${version}.tar.gz"

    cd "$BUILD_DIR"
    rm -rf "${name}-${version}"
    tar xf "$MUSLINX_SOURCES/${name}-${version}.tar.gz"
    cd "${name}-${version}"

    ./configure \
        --host="$MUSLINX_TARGET" \
        --prefix=/usr \
        --with-sysdeps="$MUSLINX_SYSROOT/usr/lib/skalibs/sysdeps" 2>/dev/null || \
    ./configure \
        --host="$MUSLINX_TARGET" \
        --prefix=/usr

    make $MAKEFLAGS
    make install DESTDIR="$MUSLINX_SYSROOT"
    echo "[✓] $name $version installed"
done

# ──────────────────────────────────────────────
# D-Bus (message bus for desktop)
# ──────────────────────────────────────────────
echo "[*] Building D-Bus..."
build_package "dbus" "1.14.10" \
    "https://dbus.freedesktop.org/releases/dbus/dbus-1.14.10.tar.xz" \
    ".tar.xz" "--disable-systemd --disable-xml-docs --disable-doxygen-docs --with-system-socket=/run/dbus/system_bus_socket"

# ──────────────────────────────────────────────
# PipeWire (audio)
# ──────────────────────────────────────────────
echo "[*] Building PipeWire..."
echo "──── Building: pipewire 1.2.7 ────"
$FETCH "https://gitlab.freedesktop.org/pipewire/pipewire/-/archive/1.2.7/pipewire-1.2.7.tar.gz" \
    "$MUSLINX_SOURCES/pipewire-1.2.7.tar.gz"
cd "$BUILD_DIR"
rm -rf "pipewire-1.2.7"
tar xf "$MUSLINX_SOURCES/pipewire-1.2.7.tar.gz"
cd "pipewire-1.2.7"

MESON_CROSS="$BUILD_DIR/muslinx-cross.ini"
meson setup builddir \
    --cross-file="$MESON_CROSS" \
    --prefix=/usr \
    --sysconfdir=/etc \
    --buildtype=release \
    -Ddocs=disabled \
    -Dtests=disabled \
    -Dsystemd=disabled \
    -Dpipewire-alsa=enabled \
    -Dspa-plugins=enabled
ninja -C builddir
DESTDIR="$MUSLINX_SYSROOT" ninja -C builddir install
echo "[✓] pipewire 1.2.7 installed"

# ──────────────────────────────────────────────
# Font packages
# ──────────────────────────────────────────────
echo "[*] Installing fonts..."
FONTS_DIR="$MUSLINX_SYSROOT/usr/share/fonts/muslinx"
mkdir -p "$FONTS_DIR"

echo "  [*] Fonts will be downloaded during system configuration (08-configure-system.sh)"

# ──────────────────────────────────────────────
# Install mpkg package manager
# ──────────────────────────────────────────────
echo "[*] Installing mpkg package manager..."
install -Dvm755 "$MUSLINX_ROOT/packages/mpkg/mpkg" "$MUSLINX_SYSROOT/usr/bin/mpkg"
install -Dvm644 "$MUSLINX_ROOT/configs/mpkg.conf" "$MUSLINX_SYSROOT/etc/mpkg/mpkg.conf"

echo ""
echo "═══════════════════════════════════════════"
echo "  Userland packages build complete!"
echo "═══════════════════════════════════════════"
