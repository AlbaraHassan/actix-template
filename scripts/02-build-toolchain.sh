#!/bin/bash
# Muslinx Linux Distribution — Cross-Toolchain Build
# Builds: Linux Headers → musl → Binutils → GCC (Pass 1) → GCC (Pass 2)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers/common.env"

echo "═══════════════════════════════════════════"
echo "  Muslinx — Phase 1: Build Cross Toolchain"
echo "═══════════════════════════════════════════"

FETCH="$SCRIPT_DIR/helpers/fetch-source.sh"
BUILD_DIR="$MUSLINX_ROOT/build"
mkdir -p "$BUILD_DIR"

# ──────────────────────────────────────────────
# Step 1: Linux Headers
# ──────────────────────────────────────────────
echo ""
echo "──── Step 1/5: Linux Headers $LINUX_VERSION ────"
$FETCH "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$LINUX_VERSION.tar.xz" \
    "$MUSLINX_SOURCES/linux-$LINUX_VERSION.tar.xz"

cd "$BUILD_DIR"
tar xf "$MUSLINX_SOURCES/linux-$LINUX_VERSION.tar.xz"
cd "linux-$LINUX_VERSION"

make mrproper
make ARCH=x86_64 headers
find usr/include -type f ! -name '*.h' -delete
mkdir -p "$MUSLINX_SYSROOT/usr/include"
cp -rv usr/include/* "$MUSLINX_SYSROOT/usr/include/"

echo "[✓] Linux headers installed"

# ──────────────────────────────────────────────
# Step 2: musl libc
# ──────────────────────────────────────────────
echo ""
echo "──── Step 2/5: musl libc $MUSL_VERSION ────"
$FETCH "https://musl.libc.org/releases/musl-$MUSL_VERSION.tar.gz" \
    "$MUSLINX_SOURCES/musl-$MUSL_VERSION.tar.gz"

cd "$BUILD_DIR"
tar xf "$MUSLINX_SOURCES/musl-$MUSL_VERSION.tar.gz"
cd "musl-$MUSL_VERSION"

./configure \
    --prefix=/usr \
    --target="$MUSLINX_TARGET"
make $MAKEFLAGS
make install DESTDIR="$MUSLINX_SYSROOT"

# Create dynamic linker symlink
mkdir -p "$MUSLINX_SYSROOT/lib"
ln -sfv /lib/ld-musl-x86_64.so.1 "$MUSLINX_SYSROOT/lib/libc.musl-x86_64.so.1"

# Create toolchain symlink so GCC can find musl
mkdir -p "$MUSLINX_TOOLCHAIN/$MUSLINX_TARGET"
ln -sfv "$MUSLINX_SYSROOT/usr/include" "$MUSLINX_TOOLCHAIN/$MUSLINX_TARGET/include"
ln -sfv "$MUSLINX_SYSROOT/usr/lib" "$MUSLINX_TOOLCHAIN/$MUSLINX_TARGET/lib"

echo "[✓] musl libc installed"

# ──────────────────────────────────────────────
# Step 3: Binutils
# ──────────────────────────────────────────────
echo ""
echo "──── Step 3/5: Binutils $BINUTILS_VERSION ────"
$FETCH "https://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_VERSION.tar.xz" \
    "$MUSLINX_SOURCES/binutils-$BINUTILS_VERSION.tar.xz"

cd "$BUILD_DIR"
tar xf "$MUSLINX_SOURCES/binutils-$BINUTILS_VERSION.tar.xz"
cd "binutils-$BINUTILS_VERSION"
mkdir -p build && cd build

../configure \
    --prefix="$MUSLINX_TOOLCHAIN" \
    --target="$MUSLINX_TARGET" \
    --with-sysroot="$MUSLINX_SYSROOT" \
    --disable-nls \
    --disable-werror \
    --enable-deterministic-archives
make $MAKEFLAGS
make install

echo "[✓] Binutils installed"

# ──────────────────────────────────────────────
# Step 4: GCC Pass 1 (C only, no threads)
# ──────────────────────────────────────────────
echo ""
echo "──── Step 4/5: GCC Pass 1 (bootstrap) $GCC_VERSION ────"
$FETCH "https://ftp.gnu.org/gnu/gcc/gcc-$GCC_VERSION/gcc-$GCC_VERSION.tar.xz" \
    "$MUSLINX_SOURCES/gcc-$GCC_VERSION.tar.xz"

cd "$BUILD_DIR"
[ -d "gcc-$GCC_VERSION" ] || tar xf "$MUSLINX_SOURCES/gcc-$GCC_VERSION.tar.xz"
cd "gcc-$GCC_VERSION"

# Download GCC prerequisites (gmp, mpfr, mpc)
./contrib/download_prerequisites || true

mkdir -p build-pass1 && cd build-pass1

../configure \
    --prefix="$MUSLINX_TOOLCHAIN" \
    --target="$MUSLINX_TARGET" \
    --with-sysroot="$MUSLINX_SYSROOT" \
    --with-newlib \
    --without-headers \
    --enable-languages=c \
    --disable-shared \
    --disable-threads \
    --disable-libssp \
    --disable-libgomp \
    --disable-libatomic \
    --disable-libquadmath \
    --disable-libvtv \
    --disable-multilib \
    --disable-nls
make $MAKEFLAGS all-gcc all-target-libgcc
make install-gcc install-target-libgcc

echo "[✓] GCC Pass 1 installed"

# ──────────────────────────────────────────────
# Step 5: GCC Pass 2 (Full C/C++ with musl)
# ──────────────────────────────────────────────
echo ""
echo "──── Step 5/5: GCC Pass 2 (full) $GCC_VERSION ────"

cd "$BUILD_DIR/gcc-$GCC_VERSION"
mkdir -p build-pass2 && cd build-pass2

../configure \
    --prefix="$MUSLINX_TOOLCHAIN" \
    --target="$MUSLINX_TARGET" \
    --with-sysroot="$MUSLINX_SYSROOT" \
    --enable-languages=c,c++ \
    --enable-threads=posix \
    --enable-tls \
    --disable-nls \
    --disable-libsanitizer \
    --disable-multilib \
    --disable-libstdcxx-pch \
    --with-build-sysroot="$MUSLINX_SYSROOT"
make $MAKEFLAGS
make install

echo "[✓] GCC Pass 2 installed"

echo ""
echo "═══════════════════════════════════════════"
echo "  Cross-toolchain build complete!"
echo "  Toolchain: $MUSLINX_TOOLCHAIN"
echo "  Target:    $MUSLINX_TARGET"
echo "═══════════════════════════════════════════"
