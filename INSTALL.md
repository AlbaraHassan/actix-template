# Muslinx Linux — Installation Guide

> Build from source, boot from ISO, or run in a virtual machine.

---

## Table of Contents

1. [System Requirements](#1-system-requirements)
2. [Building from Source](#2-building-from-source)
3. [Booting the Live ISO](#3-booting-the-live-iso)
4. [Running in a Virtual Machine](#4-running-in-a-virtual-machine)
   - [QEMU/KVM](#41-qemukvm)
   - [VirtualBox](#42-virtualbox)
   - [VMware](#43-vmware)
   - [GNOME Boxes](#44-gnome-boxes)
5. [Installing to Disk](#5-installing-to-disk)
6. [First Setup Wizard](#6-first-setup-wizard)
7. [Post-Install Configuration](#7-post-install-configuration)
8. [Troubleshooting](#8-troubleshooting)

---

## 1. System Requirements

### Build Host Requirements

To build Muslinx from source, you need a Linux machine (Ubuntu/Debian recommended) with:

| Resource       | Minimum        | Recommended     |
|----------------|----------------|-----------------|
| **OS**         | Ubuntu 22.04+  | Ubuntu 24.04    |
| **CPU**        | 4 cores        | 8+ cores        |
| **RAM**        | 4 GB           | 8+ GB           |
| **Disk Space** | 20 GB free     | 40+ GB free     |
| **Internet**   | Required       | Required        |

### Target Machine Requirements (Running Muslinx)

| Resource       | Minimum        | Recommended     |
|----------------|----------------|-----------------|
| **Arch**       | x86_64         | x86_64          |
| **CPU**        | 1 core         | 2+ cores        |
| **RAM**        | 512 MB         | 2+ GB           |
| **Disk**       | 2 GB (live)    | 10+ GB (install)|
| **GPU**        | Any with KMS   | Intel/AMD/VirtIO|
| **Boot**       | BIOS or UEFI   | UEFI            |

---

## 2. Building from Source

Muslinx is built from scratch using a 9-phase automated build pipeline. Each phase depends on the previous one.

### 2.1 Clone the Repository

```bash
git clone https://github.com/muslinx/muslinx.git
cd muslinx
```

### 2.2 Build Pipeline Overview

| Phase | Script                     | What It Does                        | Est. Time  |
|-------|----------------------------|-------------------------------------|------------|
| 1     | `01-setup-host.sh`         | Install host dependencies, set env  | 2-5 min    |
| 2     | `02-build-toolchain.sh`    | Cross-compile GCC + musl toolchain  | 30-60 min  |
| 3     | `03-build-base.sh`         | Build 30+ core system packages      | 60-90 min  |
| 4     | `04-build-kernel.sh`       | Compile Linux 6.6.70 kernel         | 10-20 min  |
| 5     | `05-build-initramfs.sh`    | Create initramfs with BusyBox       | 2-5 min    |
| 6     | `06-build-desktop.sh`      | Build Wayland/Sway desktop stack    | 30-60 min  |
| 7     | `07-build-packages.sh`     | Build s6 init, Zsh, extra packages  | 15-30 min  |
| 8     | `08-configure-system.sh`   | Configure users, services, desktop  | 1-2 min    |
| 9     | `09-create-iso.sh`         | Create bootable hybrid ISO          | 2-5 min    |

### 2.3 Run the Full Build

Run each phase sequentially. The scripts must be executed in order:

```bash
# Phase 1: Set up the build host
sudo ./scripts/01-setup-host.sh
source ./scripts/helpers/common.env

# Phase 2: Build the cross-compilation toolchain
./scripts/02-build-toolchain.sh

# Phase 3: Build core system packages
./scripts/03-build-base.sh

# Phase 4: Compile the kernel
./scripts/04-build-kernel.sh

# Phase 5: Create the initramfs
./scripts/05-build-initramfs.sh

# Phase 6: Build the desktop environment
./scripts/06-build-desktop.sh

# Phase 7: Build additional packages (s6, zsh, etc.)
./scripts/07-build-packages.sh

# Phase 8: Configure the system
./scripts/08-configure-system.sh

# Phase 9: Create the bootable ISO
sudo ./scripts/09-create-iso.sh
```

Or run everything at once:

```bash
sudo ./scripts/01-setup-host.sh
source ./scripts/helpers/common.env
for i in $(seq 2 9); do
    ./scripts/0${i}-*.sh || { echo "Phase $i failed!"; exit 1; }
done
```

### 2.4 Build Output

After a successful build, you'll find:

```
output/
├── muslinx-1.0-x86_64.iso        # Bootable hybrid ISO
├── muslinx-1.0-x86_64.iso.sha256  # SHA-256 checksum
└── muslinx-1.0-x86_64.iso.md5     # MD5 checksum
```

### 2.5 Verify the ISO

```bash
cd output
sha256sum -c muslinx-1.0-x86_64.iso.sha256
```

---

## 3. Booting the Live ISO

The Muslinx ISO is a hybrid image that supports both BIOS and UEFI boot. It can be:

- Burned to a CD/DVD
- Written to a USB drive
- Mounted in a virtual machine

### Writing to USB

```bash
# Find your USB device (be VERY careful to pick the right one)
lsblk

# Write the ISO (replace /dev/sdX with your USB device)
sudo dd if=output/muslinx-1.0-x86_64.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

> **Warning:** `dd` will overwrite everything on the target device. Double-check the device name with `lsblk` before running.

### Boot Menu Options

When you boot, GRUB presents three options:

| Option                            | Description                              |
|-----------------------------------|------------------------------------------|
| **Muslinx Linux (Live)**          | Normal boot with splash screen           |
| **Muslinx Linux (Live - Verbose)**| Boot with full kernel log output         |
| **Muslinx Linux (Console Only)**  | Boot to terminal only (no Sway desktop)  |

---

## 4. Running in a Virtual Machine

### 4.1 QEMU/KVM

QEMU with KVM is the recommended way to test Muslinx. It provides the best performance and is used by the project for testing.

#### Quick Start

```bash
qemu-system-x86_64 \
  -m 2G \
  -enable-kvm \
  -cdrom output/muslinx-1.0-x86_64.iso \
  -boot d \
  -vga virtio \
  -display gtk
```

#### Full Setup with Disk (for Persistent Install)

```bash
# 1. Create a virtual disk
qemu-img create -f qcow2 muslinx-disk.qcow2 20G

# 2. Boot from ISO with the disk attached
qemu-system-x86_64 \
  -m 2G \
  -smp 2 \
  -enable-kvm \
  -cpu host \
  -cdrom output/muslinx-1.0-x86_64.iso \
  -hda muslinx-disk.qcow2 \
  -boot d \
  -vga virtio \
  -display gtk \
  -device virtio-net-pci,netdev=net0 \
  -netdev user,id=net0 \
  -device intel-hda \
  -device hda-duplex
```

#### UEFI Boot (with OVMF)

```bash
# Install OVMF if not already present
sudo apt install ovmf

# Boot with UEFI firmware
qemu-system-x86_64 \
  -m 2G \
  -enable-kvm \
  -bios /usr/share/OVMF/OVMF_CODE.fd \
  -cdrom output/muslinx-1.0-x86_64.iso \
  -hda muslinx-disk.qcow2 \
  -boot d \
  -vga virtio \
  -display gtk
```

#### After Installing to Disk

Once Muslinx is installed to the virtual disk, boot directly from it:

```bash
qemu-system-x86_64 \
  -m 2G \
  -smp 2 \
  -enable-kvm \
  -cpu host \
  -hda muslinx-disk.qcow2 \
  -vga virtio \
  -display gtk \
  -device virtio-net-pci,netdev=net0 \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device intel-hda \
  -device hda-duplex
```

You can then SSH into the VM:

```bash
ssh -p 2222 muslinx@localhost
```

#### QEMU Flags Reference

| Flag                        | Purpose                                    |
|-----------------------------|--------------------------------------------|
| `-m 2G`                    | Allocate 2 GB RAM                           |
| `-smp 2`                   | Assign 2 CPU cores                          |
| `-enable-kvm`              | Use hardware virtualization (much faster)   |
| `-cpu host`                | Pass through host CPU features              |
| `-vga virtio`              | Use VirtIO GPU (fast, KMS-compatible)       |
| `-display gtk`             | Use GTK window for display                  |
| `-boot d`                  | Boot from CD-ROM first                      |
| `-device virtio-net-pci`   | VirtIO network adapter                      |
| `-netdev user,hostfwd=...` | Port forwarding (e.g., SSH on port 2222)    |
| `-device intel-hda`        | Intel HD Audio controller                   |

### 4.2 VirtualBox

#### Step-by-Step Setup

1. **Create a new VM:**
   - Name: `Muslinx`
   - Type: `Linux`
   - Version: `Other Linux (64-bit)`

2. **Allocate resources:**
   - RAM: 2048 MB (minimum 1024 MB)
   - Processors: 2 cores

3. **Create a virtual hard disk:**
   - Type: VDI (VirtualBox Disk Image)
   - Storage: Dynamically allocated
   - Size: 20 GB

4. **Configure settings:**
   - **System > Motherboard:**
     - Enable EFI: Optional (works with both BIOS and UEFI)
     - Boot Order: Optical first, then Hard Disk
   - **Display:**
     - Video Memory: 128 MB
     - Graphics Controller: VMSVGA or VBoxVGA
     - Enable 3D Acceleration: Optional (may help with Sway)
   - **Storage:**
     - Click the empty optical drive
     - Choose `muslinx-1.0-x86_64.iso`
   - **Network:**
     - Adapter 1: NAT (for internet) or Bridged (for LAN access)
   - **Audio:**
     - Enable Audio
     - Controller: Intel HD Audio

5. **Start the VM** and select "Muslinx Linux (Live)" from the GRUB menu.

#### VirtualBox Guest Additions

Muslinx does not ship with VirtualBox Guest Additions. For best results, use the VirtIO GPU or VMSVGA graphics controller.

### 4.3 VMware

#### VMware Workstation / Player

1. **Create a new VM:**
   - Guest OS: `Other Linux 5.x or later kernel 64-bit`

2. **Allocate resources:**
   - RAM: 2048 MB
   - Processors: 2 cores
   - Hard Disk: 20 GB (SCSI)

3. **Mount the ISO:**
   - CD/DVD: Use ISO image file > select `muslinx-1.0-x86_64.iso`
   - Check "Connect at power on"

4. **Display settings:**
   - 3D Graphics: Enable if available
   - Monitors: 1
   - Video Memory: 256 MB

5. **Network:**
   - NAT (default) or Bridged

6. **Boot** and select "Muslinx Linux (Live)" from GRUB.

> **Note:** VMware Tools are not included. Basic functionality works without them.

### 4.4 GNOME Boxes

GNOME Boxes provides the simplest VM experience on Linux:

1. Open GNOME Boxes
2. Click **+** > **Create a Virtual Machine**
3. Select **Operating System Image File** > choose `muslinx-1.0-x86_64.iso`
4. Set RAM to 2 GB and disk to 20 GB
5. Click **Create**

GNOME Boxes uses QEMU/KVM under the hood, so performance is excellent.

---

## 5. Installing to Disk

Muslinx boots as a live system by default. To install it persistently to a disk (physical or virtual), follow these steps from within the running live session.

### 5.1 Partition the Disk

```bash
# Identify your target disk
lsblk

# Partition with fdisk (example: /dev/vda or /dev/sda)
# Create two partitions:
#   1. EFI System Partition (ESP) — 512 MB, type EFI
#   2. Root partition — remaining space, type Linux
fdisk /dev/vda
```

Example partition layout:

| Partition   | Size    | Type       | Mount Point  | Format |
|-------------|---------|------------|--------------|--------|
| `/dev/vda1` | 512 MB  | EFI System | `/boot`      | vfat   |
| `/dev/vda2` | Rest    | Linux      | `/`          | ext4   |

### 5.2 Format the Partitions

```bash
mkfs.vfat -F 32 /dev/vda1
mkfs.ext4 /dev/vda2
```

### 5.3 Mount and Copy the System

```bash
# Mount the root partition
mount /dev/vda2 /mnt
mkdir -p /mnt/boot
mount /dev/vda1 /mnt/boot

# Copy the live filesystem to disk
# The live root is an overlay — copy the lower (squashfs) layer
cp -a / /mnt/ 2>/dev/null || rsync -aAXv / /mnt/ \
    --exclude=/proc --exclude=/sys --exclude=/dev \
    --exclude=/run --exclude=/tmp --exclude=/mnt \
    --exclude=/media
```

### 5.4 Configure the Installed System

```bash
# Update fstab for the installed system
cat > /mnt/etc/fstab << EOF
/dev/vda2    /        ext4     defaults          0  1
/dev/vda1    /boot    vfat     defaults          0  2
devtmpfs     /dev     devtmpfs defaults          0  0
proc         /proc    proc     defaults          0  0
sysfs        /sys     sysfs    defaults          0  0
tmpfs        /tmp     tmpfs    defaults,nosuid   0  0
tmpfs        /run     tmpfs    defaults,nosuid   0  0
EOF

# Install GRUB to the disk
mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys
chroot /mnt grub-install /dev/vda
chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# Unmount and clean up
umount /mnt/sys /mnt/proc /mnt/dev /mnt/boot /mnt
```

### 5.5 Reboot

Remove the ISO/USB and reboot:

```bash
reboot
```

The system should boot from disk into the installed Muslinx system.

---

## 6. First Setup Wizard

On the very first boot (whether live or installed), Muslinx launches a **first-setup wizard** that walks you through initial configuration:

| Step          | What It Configures                          |
|---------------|---------------------------------------------|
| **Welcome**   | Introduction and overview                   |
| **Language**   | System locale (16 languages available)     |
| **Timezone**   | Region and city (5 regions, 30+ cities)    |
| **Keyboard**   | Keyboard layout (12 layouts)               |
| **Account**    | Username, password, display name, hostname |
| **Network**    | WiFi or Ethernet configuration             |
| **Appearance** | Accent color (turquoise, gold, rose, etc.) |
| **Summary**    | Review and apply all settings              |

The wizard runs as a TUI (dialog-based) in the terminal. After completing it, the marker file `/var/lib/muslinx/.setup-done` is created so it won't run again.

### Default Live Credentials

If you skip or cancel the setup wizard, the default credentials are:

| Field     | Value     |
|-----------|-----------|
| Username  | `muslinx` |
| Password  | `muslinx` |
| Hostname  | `muslinx` |

---

## 7. Post-Install Configuration

### Desktop Keyboard Shortcuts

| Shortcut               | Action                          |
|------------------------|---------------------------------|
| `Super + Return`       | Open terminal (Foot)            |
| `Super + D`            | Open app launcher (Wofi)        |
| `Super + Shift + Q`    | Close focused window            |
| `Super + 1-9`          | Switch workspace                |
| `Super + Shift + 1-9`  | Move window to workspace        |
| `Super + L`            | Lock screen                     |
| `Super + F`            | Toggle fullscreen               |
| `Super + Shift + Space`| Toggle floating                 |
| `Super + R`            | Enter resize mode               |
| `Print`                | Screenshot (full screen)        |
| `Super + Print`        | Screenshot (select region)      |
| `Super + Shift + E`    | Exit Muslinx (logout)           |

### Package Management

```bash
# Update package index
mpkg update

# Search for a package
mpkg search firefox

# Install a package
mpkg install <package>

# Remove a package
mpkg remove <package>

# List installed packages
mpkg list

# Show package info
mpkg info <package>
```

### Key Configuration Files

| File                                    | Purpose               |
|-----------------------------------------|-----------------------|
| `~/.config/sway/config`                | Window manager config  |
| `~/.config/waybar/config.jsonc`        | Status bar modules     |
| `~/.config/waybar/style.css`           | Status bar styling     |
| `~/.config/foot/foot.ini`             | Terminal emulator      |
| `~/.zshrc`                             | Shell configuration    |
| `~/.config/muslinx/appearance.conf`   | Accent color & theme   |
| `/etc/mpkg/mpkg.conf`                 | Package manager config |

### Changing Your Shell

```bash
# Zsh is the default, Bash is also available
chsh -s /bin/bash
```

### Connecting to WiFi (Post-Install)

```bash
# Scan for networks
wpa_cli scan
wpa_cli scan_results

# Connect to a network
wpa_passphrase "NetworkName" "password" >> /etc/wpa_supplicant/wpa_supplicant.conf
wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf
dhcpcd wlan0
```

---

## 8. Troubleshooting

### Build Issues

| Problem | Solution |
|---------|----------|
| `01-setup-host.sh` fails | Ensure you're on Ubuntu/Debian and have `sudo` access |
| Toolchain build fails | Check disk space (needs 10+ GB). Ensure `build-essential` is installed |
| musl patch fails | Re-run `scripts/helpers/apply-patches.sh <package>` manually |
| `Permission denied` on scripts | Run `chmod +x scripts/*.sh scripts/helpers/*.sh` |

### Boot Issues

| Problem | Solution |
|---------|----------|
| GRUB menu doesn't appear | Try BIOS mode if UEFI fails, or vice versa |
| Black screen after GRUB | Boot with "Verbose" option to see kernel logs |
| `squashfs not found` | Ensure the ISO is mounted correctly. Try a different virtual CD drive |
| Kernel panic | Check that VirtIO drivers are enabled in the kernel config |
| No display in VM | Try `-vga std` or `-vga qxl` instead of `-vga virtio` |

### Desktop Issues

| Problem | Solution |
|---------|----------|
| Sway doesn't start | Check `~/.profile` is correct. Try running `sway` manually from tty1 |
| No Waybar | Run `waybar &` from a terminal, or check `~/.config/waybar/` |
| Black terminal | Check `~/.config/foot/foot.ini` for valid color values |
| Caps Lock not Escape | Verify `xkb_options caps:escape` is in sway config |

### VM-Specific Issues

| Problem | Solution |
|---------|----------|
| QEMU: `-enable-kvm` fails | Install `qemu-kvm` and ensure your user is in the `kvm` group. Check that virtualization is enabled in BIOS |
| VirtualBox: no display | Set Graphics Controller to VMSVGA. Increase video memory to 128 MB |
| VMware: poor graphics | Enable 3D acceleration. Use SVGA driver |
| No network in VM | Check that NAT networking is enabled. Try `dhcpcd eth0` manually |
| No sound in VM | Ensure an audio device is configured (Intel HD Audio for QEMU) |

### Getting Help

- **First-setup wizard rerun:** Delete `/var/lib/muslinx/.setup-done` and reboot
- **Emergency shell:** Boot with "Console Only" from GRUB, or press `Ctrl+Alt+F2` for tty2
- **Logs:** Check `/var/log/muslinx-setup.log` for first-setup wizard logs
