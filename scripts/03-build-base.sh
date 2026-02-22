#!/bin/bash
# Muslinx Linux Distribution — Core System Build
# Builds all base system packages against musl in the sysroot

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers/common.env"

echo "═══════════════════════════════════════════"
echo "  Muslinx — Phase 2: Build Core System"
echo "═══════════════════════════════════════════"

FETCH="$SCRIPT_DIR/helpers/fetch-source.sh"
APPLY_PATCH="$SCRIPT_DIR/helpers/apply-patches.sh"
BUILD_DIR="$MUSLINX_ROOT/build"
mkdir -p "$BUILD_DIR"

# Cross-compiler environment
export CC="${MUSLINX_TARGET}-gcc"
export CXX="${MUSLINX_TARGET}-g++"
export AR="${MUSLINX_TARGET}-ar"
export RANLIB="${MUSLINX_TARGET}-ranlib"
export STRIP="${MUSLINX_TARGET}-strip"
export PKG_CONFIG_PATH="$MUSLINX_SYSROOT/usr/lib/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="$MUSLINX_SYSROOT"

# ──────────────────────────────────────────────
# Create filesystem hierarchy
# ──────────────────────────────────────────────
echo "[*] Creating filesystem hierarchy..."
mkdir -pv "$MUSLINX_SYSROOT"/{bin,boot,dev,etc,home,lib,media,mnt,opt,proc,root,run,sbin,srv,sys,tmp,usr,var}
mkdir -pv "$MUSLINX_SYSROOT"/usr/{bin,lib,include,share,local}
mkdir -pv "$MUSLINX_SYSROOT"/var/{log,cache,spool,tmp,lib}
mkdir -pv "$MUSLINX_SYSROOT"/etc/{s6,network,mpkg}
# Merged /usr
ln -sfv usr/bin "$MUSLINX_SYSROOT/usr/sbin" 2>/dev/null || true
chmod 1777 "$MUSLINX_SYSROOT/tmp"

# Helper function to build a standard autotools package
build_package() {
    local name="$1"
    local version="$2"
    local url="$3"
    local ext="${4:-.tar.xz}"
    local configure_flags="${5:-}"
    local needs_patch="${6:-no}"

    echo ""
    echo "──── Building: $name $version ────"

    $FETCH "$url" "$MUSLINX_SOURCES/${name}-${version}${ext}"

    cd "$BUILD_DIR"
    rm -rf "${name}-${version}"
    tar xf "$MUSLINX_SOURCES/${name}-${version}${ext}"
    cd "${name}-${version}"

    if [ "$needs_patch" = "yes" ]; then
        $APPLY_PATCH "$name"
    fi

    if [ -f configure ]; then
        ./configure \
            --host="$MUSLINX_TARGET" \
            --prefix=/usr \
            --sysconfdir=/etc \
            --localstatedir=/var \
            $configure_flags
    elif [ -f Configure ]; then
        # For packages like OpenSSL that use ./Configure
        echo "[!] Non-standard configure for $name — handle manually"
        return 0
    fi

    make $MAKEFLAGS
    make install DESTDIR="$MUSLINX_SYSROOT"
    echo "[✓] $name $version installed"
}

# ──────────────────────────────────────────────
# Build packages in order
# ──────────────────────────────────────────────

# 1. zlib
build_package "zlib" "$ZLIB_VERSION" \
    "https://zlib.net/zlib-$ZLIB_VERSION.tar.xz"

# 2. xz-utils
build_package "xz" "$XZ_VERSION" \
    "https://github.com/tukaani-project/xz/releases/download/v$XZ_VERSION/xz-$XZ_VERSION.tar.xz" \
    ".tar.xz" "--disable-static"

# 3. zstd (uses Makefile, not autotools)
echo ""
echo "──── Building: zstd $ZSTD_VERSION ────"
$FETCH "https://github.com/facebook/zstd/releases/download/v$ZSTD_VERSION/zstd-$ZSTD_VERSION.tar.gz" \
    "$MUSLINX_SOURCES/zstd-$ZSTD_VERSION.tar.gz"
cd "$BUILD_DIR"
tar xf "$MUSLINX_SOURCES/zstd-$ZSTD_VERSION.tar.gz"
cd "zstd-$ZSTD_VERSION"
make $MAKEFLAGS PREFIX=/usr CC="$CC"
make install PREFIX=/usr DESTDIR="$MUSLINX_SYSROOT"
echo "[✓] zstd $ZSTD_VERSION installed"

# 4. bzip2 (uses Makefile)
echo ""
echo "──── Building: bzip2 $BZIP2_VERSION ────"
$FETCH "https://sourceware.org/pub/bzip2/bzip2-$BZIP2_VERSION.tar.gz" \
    "$MUSLINX_SOURCES/bzip2-$BZIP2_VERSION.tar.gz"
cd "$BUILD_DIR"
tar xf "$MUSLINX_SOURCES/bzip2-$BZIP2_VERSION.tar.gz"
cd "bzip2-$BZIP2_VERSION"
make $MAKEFLAGS CC="$CC" AR="$AR" RANLIB="$RANLIB" \
    PREFIX=/usr -f Makefile-libbz2_so
make $MAKEFLAGS CC="$CC" AR="$AR" RANLIB="$RANLIB" PREFIX=/usr
make install PREFIX=/usr DESTDIR="$MUSLINX_SYSROOT"
echo "[✓] bzip2 $BZIP2_VERSION installed"

# 5-7. ncurses, readline, bash
build_package "ncurses" "$NCURSES_VERSION" \
    "https://ftp.gnu.org/gnu/ncurses/ncurses-$NCURSES_VERSION.tar.gz" \
    ".tar.gz" "--with-shared --without-debug --without-ada --enable-widec --with-pkg-config-libdir=/usr/lib/pkgconfig"

build_package "readline" "$READLINE_VERSION" \
    "https://ftp.gnu.org/gnu/readline/readline-$READLINE_VERSION.tar.gz" \
    ".tar.gz" "--with-curses"

build_package "bash" "$BASH_VERSION_PKG" \
    "https://ftp.gnu.org/gnu/bash/bash-$BASH_VERSION_PKG.tar.gz" \
    ".tar.gz" "--without-bash-malloc"

# 8. coreutils (needs musl patch)
build_package "coreutils" "$COREUTILS_VERSION" \
    "https://ftp.gnu.org/gnu/coreutils/coreutils-$COREUTILS_VERSION.tar.xz" \
    ".tar.xz" "FORCE_UNSAFE_CONFIGURE=1" "yes"

# 9-16. Standard GNU tools
for pkg_info in \
    "diffutils:3.10:https://ftp.gnu.org/gnu/diffutils/diffutils-3.10.tar.xz" \
    "findutils:4.10.0:https://ftp.gnu.org/gnu/findutils/findutils-4.10.0.tar.xz" \
    "grep:3.11:https://ftp.gnu.org/gnu/grep/grep-3.11.tar.xz" \
    "gawk:5.3.1:https://ftp.gnu.org/gnu/gawk/gawk-5.3.1.tar.xz" \
    "sed:4.9:https://ftp.gnu.org/gnu/sed/sed-4.9.tar.xz" \
    "tar:1.35:https://ftp.gnu.org/gnu/tar/tar-1.35.tar.xz" \
    "make:4.4.1:https://ftp.gnu.org/gnu/make/make-4.4.1.tar.gz:.tar.gz" \
    "patch:2.7.6:https://ftp.gnu.org/gnu/patch/patch-2.7.6.tar.xz"; do
    IFS=: read -r name version url ext <<< "$pkg_info"
    build_package "$name" "$version" "$url" "${ext:-.tar.xz}"
done

# 17. util-linux (needs musl patch)
build_package "util-linux" "$UTIL_LINUX_VERSION" \
    "https://www.kernel.org/pub/linux/utils/util-linux/v${UTIL_LINUX_VERSION%.*}/util-linux-$UTIL_LINUX_VERSION.tar.xz" \
    ".tar.xz" "--disable-login --disable-su --disable-pylibmount --without-python --without-systemd" "yes"

# 18. e2fsprogs
build_package "e2fsprogs" "$E2FSPROGS_VERSION" \
    "https://downloads.sourceforge.net/project/e2fsprogs/e2fsprogs/v$E2FSPROGS_VERSION/e2fsprogs-$E2FSPROGS_VERSION.tar.gz" \
    ".tar.gz" "--disable-libblkid --disable-libuuid --disable-fsck --disable-uuidd"

# 19. kmod
build_package "kmod" "$KMOD_VERSION" \
    "https://www.kernel.org/pub/linux/utils/kernel/kmod/kmod-$KMOD_VERSION.tar.xz" \
    ".tar.xz" "--with-xz --with-zlib --with-zstd"

# 20. eudev
build_package "eudev" "$EUDEV_VERSION" \
    "https://github.com/eudev-project/eudev/releases/download/v$EUDEV_VERSION/eudev-$EUDEV_VERSION.tar.gz" \
    ".tar.gz" "--disable-manpages --disable-introspection"

# 21. shadow
build_package "shadow" "$SHADOW_VERSION" \
    "https://github.com/shadow-maint/shadow/releases/download/$SHADOW_VERSION/shadow-$SHADOW_VERSION.tar.xz" \
    ".tar.xz" "--with-group-name-max-length=32"

# 22. LibreSSL
echo ""
echo "──── Building: LibreSSL $LIBRESSL_VERSION ────"
$FETCH "https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-$LIBRESSL_VERSION.tar.gz" \
    "$MUSLINX_SOURCES/libressl-$LIBRESSL_VERSION.tar.gz"
cd "$BUILD_DIR"
tar xf "$MUSLINX_SOURCES/libressl-$LIBRESSL_VERSION.tar.gz"
cd "libressl-$LIBRESSL_VERSION"
./configure \
    --host="$MUSLINX_TARGET" \
    --prefix=/usr \
    --sysconfdir=/etc
make $MAKEFLAGS
make install DESTDIR="$MUSLINX_SYSROOT"
echo "[✓] LibreSSL $LIBRESSL_VERSION installed"

# 23. curl
build_package "curl" "$CURL_VERSION" \
    "https://curl.se/download/curl-$CURL_VERSION.tar.xz" \
    ".tar.xz" "--with-openssl --enable-threaded-resolver"

# 24. iproute2 (uses Makefile)
echo ""
echo "──── Building: iproute2 $IPROUTE2_VERSION ────"
$FETCH "https://www.kernel.org/pub/linux/utils/net/iproute2/iproute2-$IPROUTE2_VERSION.tar.xz" \
    "$MUSLINX_SOURCES/iproute2-$IPROUTE2_VERSION.tar.xz"
cd "$BUILD_DIR"
tar xf "$MUSLINX_SOURCES/iproute2-$IPROUTE2_VERSION.tar.xz"
cd "iproute2-$IPROUTE2_VERSION"
./configure --prefix=/usr
make $MAKEFLAGS CC="$CC"
make install DESTDIR="$MUSLINX_SYSROOT"
echo "[✓] iproute2 $IPROUTE2_VERSION installed"

# 25. dhcpcd
build_package "dhcpcd" "$DHCPCD_VERSION" \
    "https://github.com/NetworkConfiguration/dhcpcd/releases/download/v$DHCPCD_VERSION/dhcpcd-$DHCPCD_VERSION.tar.xz" \
    ".tar.xz" "--sysconfdir=/etc --dbdir=/var/lib/dhcpcd --rundir=/run/dhcpcd"

echo ""
echo "═══════════════════════════════════════════"
echo "  Core system build complete!"
echo "═══════════════════════════════════════════"
