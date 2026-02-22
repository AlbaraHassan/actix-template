#!/bin/bash
# Muslinx Linux Distribution — ISO Creation
# Packages the built system into a bootable hybrid ISO

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers/common.env"

echo "═══════════════════════════════════════════"
echo "  Muslinx — Phase 7: Create Bootable ISO"
echo "═══════════════════════════════════════════"

ISO_DIR="$MUSLINX_ROOT/iso"
OUTPUT_DIR="$MUSLINX_ROOT/output"
SYSROOT="$MUSLINX_SYSROOT"
ISO_NAME="muslinx-1.0-x86_64.iso"

# Clean staging area
rm -rf "$ISO_DIR"
mkdir -p "$ISO_DIR"/{boot/grub,EFI/BOOT,isolinux}
mkdir -p "$OUTPUT_DIR"

# ──────────────────────────────────────────────
# Step 1: Create SquashFS image of root filesystem
# ──────────────────────────────────────────────
echo "[*] Creating SquashFS image of root filesystem..."
mksquashfs "$SYSROOT" "$ISO_DIR/muslinx.squashfs" \
    -comp zstd \
    -Xcompression-level 19 \
    -b 1M \
    -noappend \
    -no-recovery \
    -e "$SYSROOT/boot" \
    -e "$SYSROOT/dev" \
    -e "$SYSROOT/proc" \
    -e "$SYSROOT/sys" \
    -e "$SYSROOT/tmp" \
    -e "$SYSROOT/run"

echo "[✓] SquashFS image created"

# ──────────────────────────────────────────────
# Step 2: Copy kernel and initramfs
# ──────────────────────────────────────────────
echo "[*] Copying kernel and initramfs..."
cp "$SYSROOT/boot/vmlinuz-muslinx" "$ISO_DIR/boot/vmlinuz"
cp "$SYSROOT/boot/initramfs-muslinx.img" "$ISO_DIR/boot/initramfs.img"

# ──────────────────────────────────────────────
# Step 3: Configure GRUB (BIOS + UEFI)
# ──────────────────────────────────────────────
echo "[*] Configuring GRUB bootloader..."

# Copy GRUB config
cp "$MUSLINX_ROOT/configs/grub.cfg" "$ISO_DIR/boot/grub/grub.cfg"

# Create UEFI boot image
echo "[*] Creating UEFI boot image..."
UEFI_IMG="$ISO_DIR/EFI/BOOT/efi.img"
dd if=/dev/zero of="$UEFI_IMG" bs=1M count=16
mkfs.vfat "$UEFI_IMG"
UEFI_MNT=$(mktemp -d)
mount -o loop "$UEFI_IMG" "$UEFI_MNT"
mkdir -p "$UEFI_MNT/EFI/BOOT"

# Build GRUB EFI binary
grub-mkstandalone \
    --format=x86_64-efi \
    --output="$UEFI_MNT/EFI/BOOT/BOOTX64.EFI" \
    --locales="" \
    --fonts="" \
    "boot/grub/grub.cfg=$ISO_DIR/boot/grub/grub.cfg"

umount "$UEFI_MNT"
rmdir "$UEFI_MNT"

# Create BIOS boot image
echo "[*] Creating BIOS boot image..."
grub-mkstandalone \
    --format=i386-pc \
    --output="$ISO_DIR/boot/grub/bios.img" \
    --install-modules="linux normal iso9660 biosdisk memdisk search tar ls" \
    --modules="linux normal iso9660 biosdisk search" \
    --locales="" \
    --fonts="" \
    "boot/grub/grub.cfg=$ISO_DIR/boot/grub/grub.cfg"

cat /usr/lib/grub/i386-pc/cdboot.img "$ISO_DIR/boot/grub/bios.img" \
    > "$ISO_DIR/boot/grub/bios-combined.img"

# ──────────────────────────────────────────────
# Step 4: Create hybrid ISO
# ──────────────────────────────────────────────
echo "[*] Creating hybrid ISO image..."
xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "MUSLINX" \
    -appid "Muslinx Linux 1.0" \
    -eltorito-boot boot/grub/bios-combined.img \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    --eltorito-catalog boot/grub/boot.cat \
    --grub2-boot-info \
    --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
    -eltorito-alt-boot \
    -e EFI/BOOT/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -output "$OUTPUT_DIR/$ISO_NAME" \
    "$ISO_DIR"

echo "[✓] ISO created: $OUTPUT_DIR/$ISO_NAME"

# ──────────────────────────────────────────────
# Step 5: Generate checksums
# ──────────────────────────────────────────────
echo "[*] Generating checksums..."
cd "$OUTPUT_DIR"
sha256sum "$ISO_NAME" > "$ISO_NAME.sha256"
md5sum "$ISO_NAME" > "$ISO_NAME.md5"

ISO_SIZE=$(du -h "$OUTPUT_DIR/$ISO_NAME" | cut -f1)

echo ""
echo "═══════════════════════════════════════════"
echo "  ISO creation complete!"
echo ""
echo "  File: $OUTPUT_DIR/$ISO_NAME"
echo "  Size: $ISO_SIZE"
echo ""
echo "  Test with QEMU:"
echo "  qemu-system-x86_64 \\"
echo "    -m 2G \\"
echo "    -enable-kvm \\"
echo "    -cdrom $OUTPUT_DIR/$ISO_NAME \\"
echo "    -boot d \\"
echo "    -vga virtio \\"
echo "    -display gtk"
echo "═══════════════════════════════════════════"
