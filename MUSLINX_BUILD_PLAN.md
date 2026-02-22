# Muslinx Linux Distribution — Build Plan

> **Purpose:** A step-by-step, Claude Code–executable plan to build a custom Linux distro called **Muslinx** — a lightweight, musl-based Linux distribution with a full graphical desktop.

---

## 1. Project Overview

| Property | Value |
|---|---|
| **Name** | Muslinx |
| **Base** | Built from scratch (Linux From Scratch approach) |
| **C Library** | musl libc (not glibc) |
| **Init System** | s6 + s6-rc (lightweight, supervision-based) |
| **Package Manager** | Custom `mpkg` (shell-based, binary + source support) |
| **Desktop** | Sway (Wayland compositor) + Waybar + Foot terminal |
| **Shell** | Zsh (default), Bash available |
| **Target** | x86_64, bootable ISO for VM testing (QEMU/VirtualBox) |
| **Toolchain** | GCC cross-compiled with musl |
| **Boot** | GRUB 2 (BIOS + UEFI) |
| **Kernel** | Linux 6.x LTS (latest stable at build time) |

---

## 2. Directory Structure

```
muslinx/
├── MUSLINX_BUILD_PLAN.md
├── scripts/
│   ├── 01-setup-host.sh
│   ├── 02-build-toolchain.sh
│   ├── 03-build-base.sh
│   ├── 04-build-kernel.sh
│   ├── 05-build-initramfs.sh
│   ├── 06-build-desktop.sh
│   ├── 07-build-packages.sh
│   ├── 08-configure-system.sh
│   ├── 09-create-iso.sh
│   └── helpers/
│       ├── fetch-source.sh
│       ├── apply-patches.sh
│       └── chroot-run.sh
├── patches/
│   ├── coreutils-musl.patch
│   ├── util-linux-musl.patch
│   └── ...
├── configs/
│   ├── kernel.config
│   ├── grub.cfg
│   ├── sway-config
│   ├── waybar-config.jsonc
│   ├── waybar-style.css
│   ├── foot.ini
│   ├── zshrc
│   ├── hostname
│   ├── resolv.conf
│   ├── network/
│   └── mpkg.conf
├── branding/
│   ├── wallpaper.png
│   ├── logo.svg
│   ├── plymouth-theme/
│   └── grub-theme/
├── packages/
│   └── mpkg/
│       ├── mpkg
│       ├── repo-index
│       └── build-recipes/
├── rootfs/
├── iso/
└── output/
```

---

## 3. Phase 1 — Host Setup & Toolchain

### 3.1 Host Prerequisites

```bash
# Required on host (Ubuntu/Debian build machine)
sudo apt update && sudo apt install -y \
  build-essential bison flex texinfo gawk curl wget \
  xz-utils python3 perl m4 patch file bc cpio \
  libssl-dev libelf-dev grub-pc-bin grub-efi-amd64-bin \
  xorriso mtools dosfstools squashfs-tools \
  qemu-system-x86 ovmf git autoconf automake libtool \
  pkg-config cmake meson ninja-build gettext

# Set build variables
export MUSLINX_ROOT=$(pwd)/muslinx
export MUSLINX_TARGET=x86_64-muslinx-linux-musl
export MUSLINX_TOOLCHAIN=$MUSLINX_ROOT/toolchain
export MUSLINX_SYSROOT=$MUSLINX_ROOT/rootfs
export MUSLINX_SOURCES=$MUSLINX_ROOT/sources
export PATH=$MUSLINX_TOOLCHAIN/bin:$PATH
export MAKEFLAGS="-j$(nproc)"
```

### 3.2 Build Cross Toolchain

Build order (each depends on the previous):

| # | Package | Version | Purpose |
|---|---------|---------|---------|
| 1 | Linux Headers | 6.x | Kernel API headers |
| 2 | musl libc | 1.2.x | C standard library |
| 3 | Binutils | 2.42+ | Assembler, linker |
| 4 | GCC (Pass 1) | 14.x | Bootstrap C compiler |
| 5 | GCC (Pass 2) | 14.x | Full C/C++ compiler with musl |

---

## 4. Phase 2 — Core System

### 4.1 Filesystem Hierarchy

Standard FHS layout with merged /usr.

### 4.2 Core Packages Build Order

| # | Package | Notes |
|---|---------|-------|
| 1 | zlib | Compression library |
| 2 | xz-utils | LZMA compression |
| 3 | zstd | Zstandard compression |
| 4 | bzip2 | Compression |
| 5 | file | File type detection |
| 6 | readline | Line editing |
| 7 | ncurses | Terminal UI library |
| 8 | bash | Shell (secondary) |
| 9 | coreutils | Core UNIX utilities — needs musl patch |
| 10 | diffutils | Diff tools |
| 11 | findutils | find, xargs |
| 12 | grep | Pattern matching |
| 13 | gawk | AWK |
| 14 | sed | Stream editor |
| 15 | tar | Archiving |
| 16 | make | Build tool |
| 17 | patch | Patching |
| 18 | util-linux | System utilities — needs musl patch |
| 19 | e2fsprogs | ext4 filesystem tools |
| 20 | kmod | Kernel module tools |
| 21 | eudev | Device manager (udev fork, musl-compatible) |
| 22 | shadow | User management |
| 23 | openssh | SSH client & server |
| 24 | curl | HTTP client |
| 25 | ca-certificates | TLS trust store |
| 26 | openssl / libressl | TLS library |
| 27 | iproute2 | Network tools |
| 28 | dhcpcd | DHCP client |
| 29 | wpa_supplicant | WiFi |
| 30 | iptables / nftables | Firewall |

### 4.3 Known musl Incompatibilities & Fixes

| Issue | Affected Packages | Fix |
|-------|------------------|-----|
| No `strtod_l` / `locale_t` | coreutils, glib | Patch to use `strtod()` or add stub |
| No `wordexp()` | some shells | Patch or use alternative |
| No `rpc/rpc.h` | libtirpc-dependent | Build libtirpc first |
| `__MUSL__` not defined | Various | Check with `#if defined(__linux__) && !defined(__GLIBC__)` |
| No `execinfo.h` (backtrace) | mesa, glib | Use libunwind or disable backtrace |
| No `sys/cdefs.h` | Some BSD-origin code | Create stub or patch includes |
| No `error.h` | gnulib-based | Patch to use `fprintf(stderr, ...)` |

---

## 5. Phase 3 — Init System (s6 + s6-rc)

### 5.1 Build s6 Stack

| # | Package | Purpose |
|---|---------|---------|
| 1 | skalibs | Low-level C library for s6 |
| 2 | execline | Scripting language for s6 |
| 3 | s6 | Process supervision |
| 4 | s6-linux-init | PID 1 / init replacement |
| 5 | s6-rc | Service manager (dependency-based) |

### 5.2 Boot Sequence

```
GRUB → Linux Kernel → initramfs → s6-linux-init (PID 1) →
  → mount-filesystems (oneshot)
  → eudevd → seatd → dbus
  → syslogd
  → dhcpcd
  → tty1, tty2 (getty)
  → [user logs in → starts Sway via ~/.profile]
```

---

## 6. Phase 4 — Linux Kernel

Custom kernel configuration targeting x86_64 with:
- VirtIO drivers for VM testing
- DRM/KMS for graphics (Intel, AMD, Nouveau, VirtIO GPU, Bochs)
- EFI stub support
- SquashFS + OverlayFS for live ISO
- Standard filesystems (ext4, vfat, tmpfs, fuse)
- Input drivers (evdev, USB HID)
- Audio (HDA Intel)
- Network (VirtIO, standard Ethernet)

---

## 7. Phase 5 — Custom UI Design System (Islamic Art-Inspired)

### Design Philosophy

Muslinx's UI is inspired by Islamic geometric art, calligraphy, and Iznik tilework.
The aesthetic blends mathematical precision of traditional arabesque patterns with
modern dark-mode minimalism.

### Color Palette

| Token | Hex | Inspiration |
|-------|-----|-------------|
| midnight | #0d1117 | Deepest background |
| night-sky | #141824 | Panels, sidebars |
| surface | #1c2233 | Cards, windows |
| turquoise | #2ec4b6 | Primary — Iznik ceramic blue-green |
| gold | #d4a853 | Secondary — calligraphy ink, dome gilding |
| rose | #e8637a | Destructive/alerts — Persian rose |
| ivory | #f0ead6 | High emphasis — parchment |

### Typography

| Role | Font | Rationale |
|------|------|-----------|
| Display / Branding | Amiri (serif) | Arabic calligraphy-inspired Naskh |
| UI / Body | Outfit (sans) | Clean geometric sans |
| Terminal / Code | IBM Plex Mono | Code readability |
| Arabic fallback | Noto Naskh Arabic | Full Arabic Unicode support |

### Desktop Stack

- **Window Manager:** Sway (Wayland compositor)
- **Status Bar:** Waybar
- **Terminal:** Foot
- **Launcher:** Wofi
- **Notifications:** Mako
- **GTK Theme:** Custom Muslinx theme (based on Adwaita-dark)
- **Icon Theme:** Papirus-Dark with turquoise folder variant
- **Cursor Theme:** Bibata-Modern-Classic

---

## 8. Phase 6 — Package Manager (mpkg)

Shell-based package manager supporting:
- Binary package installation from repos
- Source builds from recipes
- Dependency resolution
- Package tracking database

---

## 9. Phase 7 — ISO Creation

- SquashFS compressed root filesystem
- OverlayFS for live session writability
- GRUB 2 bootloader (BIOS + UEFI)
- Hybrid ISO (dd-able to USB)
- Automated QEMU test boot

---

## 10. Testing

```bash
# Boot in QEMU
qemu-system-x86_64 \
  -m 2G \
  -enable-kvm \
  -cdrom output/muslinx-1.0.iso \
  -boot d \
  -vga virtio \
  -display gtk
```
