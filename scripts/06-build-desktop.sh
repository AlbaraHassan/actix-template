#!/bin/bash
# Muslinx Linux Distribution — Desktop Environment Build
# Builds Wayland/Sway desktop stack with all dependencies

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers/common.env"

echo "═══════════════════════════════════════════"
echo "  Muslinx — Phase 5: Build Desktop Stack"
echo "═══════════════════════════════════════════"

FETCH="$SCRIPT_DIR/helpers/fetch-source.sh"
BUILD_DIR="$MUSLINX_ROOT/build"
mkdir -p "$BUILD_DIR"

export CC="${MUSLINX_TARGET}-gcc"
export CXX="${MUSLINX_TARGET}-g++"
export PKG_CONFIG_PATH="$MUSLINX_SYSROOT/usr/lib/pkgconfig:$MUSLINX_SYSROOT/usr/share/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="$MUSLINX_SYSROOT"

# Meson cross-file for Wayland stack
MESON_CROSS="$BUILD_DIR/muslinx-cross.ini"
cat > "$MESON_CROSS" << EOF
[binaries]
c = '${MUSLINX_TARGET}-gcc'
cpp = '${MUSLINX_TARGET}-g++'
ar = '${MUSLINX_TARGET}-ar'
strip = '${MUSLINX_TARGET}-strip'
pkgconfig = 'pkg-config'

[host_machine]
system = 'linux'
cpu_family = 'x86_64'
cpu = 'x86_64'
endian = 'little'

[properties]
sys_root = '$MUSLINX_SYSROOT'
pkg_config_libdir = '$MUSLINX_SYSROOT/usr/lib/pkgconfig:$MUSLINX_SYSROOT/usr/share/pkgconfig'
EOF

# Helper for meson builds
build_meson() {
    local name="$1"
    local version="$2"
    local url="$3"
    local ext="${4:-.tar.xz}"
    local extra_args="${5:-}"

    echo ""
    echo "──── Building (meson): $name $version ────"

    $FETCH "$url" "$MUSLINX_SOURCES/${name}-${version}${ext}"

    cd "$BUILD_DIR"
    rm -rf "${name}-${version}"
    tar xf "$MUSLINX_SOURCES/${name}-${version}${ext}"
    cd "${name}-${version}"

    meson setup builddir \
        --cross-file="$MESON_CROSS" \
        --prefix=/usr \
        --sysconfdir=/etc \
        --buildtype=release \
        $extra_args

    ninja -C builddir
    DESTDIR="$MUSLINX_SYSROOT" ninja -C builddir install
    echo "[✓] $name $version installed"
}

# Helper for autotools builds
build_auto() {
    local name="$1"
    local version="$2"
    local url="$3"
    local ext="${4:-.tar.xz}"
    local extra_args="${5:-}"

    echo ""
    echo "──── Building (autotools): $name $version ────"

    $FETCH "$url" "$MUSLINX_SOURCES/${name}-${version}${ext}"

    cd "$BUILD_DIR"
    rm -rf "${name}-${version}"
    tar xf "$MUSLINX_SOURCES/${name}-${version}${ext}"
    cd "${name}-${version}"

    ./configure \
        --host="$MUSLINX_TARGET" \
        --prefix=/usr \
        --sysconfdir=/etc \
        $extra_args
    make $MAKEFLAGS
    make install DESTDIR="$MUSLINX_SYSROOT"
    echo "[✓] $name $version installed"
}

# ──────────────────────────────────────────────
# Wayland Protocol Libraries
# ──────────────────────────────────────────────
echo "[*] Building Wayland protocol stack..."

build_meson "wayland" "1.23.0" \
    "https://gitlab.freedesktop.org/wayland/wayland/-/releases/1.23.0/downloads/wayland-1.23.0.tar.xz" \
    ".tar.xz" "-Ddocumentation=false -Dtests=false"

build_meson "wayland-protocols" "1.38" \
    "https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/1.38/downloads/wayland-protocols-1.38.tar.xz" \
    ".tar.xz" "-Dtests=false"

# ──────────────────────────────────────────────
# Graphics Libraries
# ──────────────────────────────────────────────
echo "[*] Building graphics libraries..."

build_meson "libdrm" "2.4.123" \
    "https://dri.freedesktop.org/libdrm/libdrm-2.4.123.tar.xz" \
    ".tar.xz" "-Dintel=enabled -Dradeon=enabled -Damdgpu=enabled -Dnouveau=enabled -Dvmwgfx=enabled"

build_meson "pixman" "0.44.2" \
    "https://cairographics.org/releases/pixman-0.44.2.tar.gz" \
    ".tar.gz" ""

build_meson "mesa" "24.3.0" \
    "https://archive.mesa3d.org/mesa-24.3.0.tar.xz" \
    ".tar.xz" "-Dplatforms=wayland -Dgallium-drivers=swrast,virgl -Dvulkan-drivers= -Dglx=disabled -Degl=enabled -Dgles2=enabled -Dllvm=disabled"

# ──────────────────────────────────────────────
# Input Libraries
# ──────────────────────────────────────────────
echo "[*] Building input libraries..."

build_meson "libinput" "1.26.2" \
    "https://gitlab.freedesktop.org/libinput/libinput/-/releases/1.26.2/downloads/libinput-1.26.2.tar.xz" \
    ".tar.xz" "-Ddocumentation=false -Dtests=false -Ddebug-gui=false"

build_auto "libxkbcommon" "1.7.0" \
    "https://xkbcommon.org/download/libxkbcommon-1.7.0.tar.xz" \
    ".tar.xz" "--disable-x11"

# ──────────────────────────────────────────────
# Seat Management
# ──────────────────────────────────────────────
echo "[*] Building seat management..."

build_meson "seatd" "0.9.1" \
    "https://git.sr.ht/~kennylevinsen/seatd/archive/0.9.1.tar.gz" \
    ".tar.gz" "-Dserver=enabled -Dlibseat-builtin=enabled"

# ──────────────────────────────────────────────
# wlroots (Sway's compositor library)
# ──────────────────────────────────────────────
echo "[*] Building wlroots..."

build_meson "wlroots" "$WLROOTS_VERSION" \
    "https://gitlab.freedesktop.org/wlroots/wlroots/-/releases/$WLROOTS_VERSION/downloads/wlroots-$WLROOTS_VERSION.tar.gz" \
    ".tar.gz" "-Dexamples=false -Dbackends=drm,libinput -Drenderers=gles2"

# ──────────────────────────────────────────────
# Sway Window Manager
# ──────────────────────────────────────────────
echo "[*] Building Sway..."

build_meson "sway" "$SWAY_VERSION" \
    "https://github.com/swaywm/sway/releases/download/$SWAY_VERSION/sway-$SWAY_VERSION.tar.gz" \
    ".tar.gz" "-Dman-pages=disabled -Dswaybar=true -Dswaynag=true"

# ──────────────────────────────────────────────
# Desktop Utilities
# ──────────────────────────────────────────────
echo "[*] Building desktop utilities..."

# Waybar (status bar)
build_meson "Waybar" "$WAYBAR_VERSION" \
    "https://github.com/Alexays/Waybar/archive/$WAYBAR_VERSION.tar.gz" \
    ".tar.gz" "-Dtests=disabled -Dman-pages=disabled"

# Foot terminal
build_meson "foot" "$FOOT_VERSION" \
    "https://codeberg.org/dnkl/foot/archive/$FOOT_VERSION.tar.gz" \
    ".tar.gz" "-Ddocs=disabled -Dthemes=true"

# Wofi (app launcher)
build_meson "wofi" "0.7" \
    "https://hg.sr.ht/~scoopta/wofi/archive/v0.7.tar.gz" \
    ".tar.gz" ""

# Mako (notification daemon)
build_meson "mako" "1.9.0" \
    "https://github.com/emersion/mako/releases/download/v1.9.0/mako-1.9.0.tar.gz" \
    ".tar.gz" ""

# Grim (screenshot tool)
build_meson "grim" "1.4.1" \
    "https://git.sr.ht/~emersion/grim/archive/v1.4.1.tar.gz" \
    ".tar.gz" ""

# Slurp (screen region selector)
build_meson "slurp" "1.5.0" \
    "https://github.com/emersion/slurp/releases/download/v1.5.0/slurp-1.5.0.tar.gz" \
    ".tar.gz" ""

# Swaylock (screen locker)
build_meson "swaylock" "1.8.0" \
    "https://github.com/swaywm/swaylock/releases/download/v1.8.0/swaylock-1.8.0.tar.gz" \
    ".tar.gz" ""

# wl-clipboard
build_meson "wl-clipboard" "2.2.1" \
    "https://github.com/bugaevc/wl-clipboard/releases/download/v2.2.1/wl-clipboard-2.2.1.tar.gz" \
    ".tar.gz" ""

# ──────────────────────────────────────────────
# Zsh (default shell)
# ──────────────────────────────────────────────
echo "[*] Building Zsh..."

build_auto "zsh" "$ZSH_VERSION_PKG" \
    "https://sourceforge.net/projects/zsh/files/zsh/$ZSH_VERSION_PKG/zsh-$ZSH_VERSION_PKG.tar.xz" \
    ".tar.xz" "--enable-multibyte --enable-pcre --with-tcsetpgrp"

echo ""
echo "═══════════════════════════════════════════"
echo "  Desktop stack build complete!"
echo "  Components: Sway, Waybar, Foot, Wofi,"
echo "  Mako, Grim, Slurp, Swaylock, Zsh"
echo "═══════════════════════════════════════════"
