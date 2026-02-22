#!/bin/bash
# Muslinx Linux Distribution — System Configuration
# Configures fstab, networking, users, services, and desktop environment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/helpers/common.env"

echo "═══════════════════════════════════════════"
echo "  Muslinx — Phase 6: System Configuration"
echo "═══════════════════════════════════════════"

CONFIGS_DIR="$MUSLINX_ROOT/configs"
BRANDING_DIR="$MUSLINX_ROOT/branding"
SYSROOT="$MUSLINX_SYSROOT"

# ──────────────────────────────────────────────
# /etc/fstab
# ──────────────────────────────────────────────
echo "[*] Creating /etc/fstab..."
cat > "$SYSROOT/etc/fstab" << 'EOF'
# Muslinx /etc/fstab
# <device>     <mount>  <type>   <options>         <dump> <pass>
devtmpfs       /dev     devtmpfs defaults          0      0
proc           /proc    proc     defaults          0      0
sysfs          /sys     sysfs    defaults          0      0
tmpfs          /tmp     tmpfs    defaults,nosuid   0      0
tmpfs          /run     tmpfs    defaults,nosuid   0      0
# Root filesystem (uncomment and set for installed system)
# /dev/sda2    /        ext4     defaults          0      1
# /dev/sda1    /boot    vfat     defaults          0      2
EOF

# ──────────────────────────────────────────────
# Hostname & hosts
# ──────────────────────────────────────────────
echo "[*] Setting hostname..."
cp "$CONFIGS_DIR/hostname" "$SYSROOT/etc/hostname"
cat > "$SYSROOT/etc/hosts" << 'EOF'
127.0.0.1   localhost
127.0.1.1   muslinx
::1         localhost ip6-localhost ip6-loopback
EOF

# ──────────────────────────────────────────────
# DNS
# ──────────────────────────────────────────────
echo "[*] Configuring DNS..."
cp "$CONFIGS_DIR/resolv.conf" "$SYSROOT/etc/resolv.conf"

# ──────────────────────────────────────────────
# User accounts
# ──────────────────────────────────────────────
echo "[*] Creating user accounts..."

# Create /etc/passwd
cat > "$SYSROOT/etc/passwd" << 'EOF'
root:x:0:0:root:/root:/bin/zsh
daemon:x:1:1:daemon:/usr/sbin:/bin/false
nobody:x:65534:65534:nobody:/nonexistent:/bin/false
seatd:x:100:100:seatd:/var/run/seatd:/bin/false
dbus:x:101:101:D-Bus:/var/run/dbus:/bin/false
muslinx:x:1000:1000:Muslinx User:/home/muslinx:/bin/zsh
EOF

# Create /etc/group
cat > "$SYSROOT/etc/group" << 'EOF'
root:x:0:
daemon:x:1:
tty:x:5:muslinx
disk:x:6:
audio:x:11:muslinx
video:x:12:muslinx
input:x:13:muslinx
seat:x:100:muslinx
dbus:x:101:
users:x:1000:muslinx
EOF

# Create /etc/shadow (password: muslinx)
cat > "$SYSROOT/etc/shadow" << 'EOF'
root:!:19700:0:99999:7:::
daemon:!:19700:0:99999:7:::
nobody:!:19700:0:99999:7:::
seatd:!:19700:0:99999:7:::
dbus:!:19700:0:99999:7:::
muslinx:$6$muslinx$placeholder:19700:0:99999:7:::
EOF
chmod 640 "$SYSROOT/etc/shadow"

# Create home directory
mkdir -p "$SYSROOT/home/muslinx"
mkdir -p "$SYSROOT/home/muslinx/.config"/{sway,waybar,foot}
mkdir -p "$SYSROOT/home/muslinx"/{Documents,Downloads,Pictures,Music,Videos}

# ──────────────────────────────────────────────
# Shell configuration
# ──────────────────────────────────────────────
echo "[*] Installing shell configuration..."
cp "$CONFIGS_DIR/zshrc" "$SYSROOT/home/muslinx/.zshrc"
cp "$CONFIGS_DIR/zshrc" "$SYSROOT/etc/skel/.zshrc"

# .profile to auto-start Sway on tty1
cat > "$SYSROOT/home/muslinx/.profile" << 'EOF'
# Auto-start Sway on tty1
if [ "$(tty)" = "/dev/tty1" ] && [ -z "$WAYLAND_DISPLAY" ]; then
    export XDG_SESSION_TYPE=wayland
    export XDG_CURRENT_DESKTOP=sway
    export MOZ_ENABLE_WAYLAND=1
    export QT_QPA_PLATFORM=wayland
    exec sway
fi
EOF

# ──────────────────────────────────────────────
# Desktop environment configs
# ──────────────────────────────────────────────
echo "[*] Installing desktop configuration..."

# Sway config
cp "$CONFIGS_DIR/sway-config" "$SYSROOT/home/muslinx/.config/sway/config"
cp "$CONFIGS_DIR/sway-config" "$SYSROOT/etc/sway/config" 2>/dev/null || \
    (mkdir -p "$SYSROOT/etc/sway" && cp "$CONFIGS_DIR/sway-config" "$SYSROOT/etc/sway/config")

# Waybar config
cp "$CONFIGS_DIR/waybar-config.jsonc" "$SYSROOT/home/muslinx/.config/waybar/config.jsonc"
cp "$CONFIGS_DIR/waybar-style.css" "$SYSROOT/home/muslinx/.config/waybar/style.css"

# Foot terminal config
cp "$CONFIGS_DIR/foot.ini" "$SYSROOT/home/muslinx/.config/foot/foot.ini"

# ──────────────────────────────────────────────
# Branding & wallpaper
# ──────────────────────────────────────────────
echo "[*] Installing branding..."
mkdir -p "$SYSROOT/usr/share/muslinx"
if [ -f "$BRANDING_DIR/wallpaper.png" ]; then
    cp "$BRANDING_DIR/wallpaper.png" "$SYSROOT/usr/share/muslinx/wallpaper.png"
fi
if [ -f "$BRANDING_DIR/logo.svg" ]; then
    cp "$BRANDING_DIR/logo.svg" "$SYSROOT/usr/share/muslinx/logo.svg"
fi

# ──────────────────────────────────────────────
# GTK theme
# ──────────────────────────────────────────────
echo "[*] Installing GTK theme..."
GTK_THEME_DIR="$SYSROOT/usr/share/themes/Muslinx"
mkdir -p "$GTK_THEME_DIR/gtk-3.0"
mkdir -p "$GTK_THEME_DIR/gtk-4.0"

if [ -f "$BRANDING_DIR/gtk3-theme.css" ]; then
    cp "$BRANDING_DIR/gtk3-theme.css" "$GTK_THEME_DIR/gtk-3.0/gtk.css"
    cp "$BRANDING_DIR/gtk3-theme.css" "$GTK_THEME_DIR/gtk-4.0/gtk.css"
fi

# GTK settings
mkdir -p "$SYSROOT/home/muslinx/.config/gtk-3.0"
cat > "$SYSROOT/home/muslinx/.config/gtk-3.0/settings.ini" << 'EOF'
[Settings]
gtk-theme-name=Muslinx
gtk-icon-theme-name=Papirus-Dark
gtk-cursor-theme-name=Bibata-Modern-Classic
gtk-font-name=Outfit 10
gtk-application-prefer-dark-theme=true
EOF

# ──────────────────────────────────────────────
# s6 service definitions
# ──────────────────────────────────────────────
echo "[*] Creating s6 service definitions..."

# mount-filesystems (oneshot)
SV_DIR="$SYSROOT/etc/s6/sv"
mkdir -p "$SV_DIR"

create_oneshot() {
    local name="$1"
    local up_cmd="$2"
    local down_cmd="${3:-}"

    mkdir -p "$SV_DIR/$name"
    echo "oneshot" > "$SV_DIR/$name/type"
    echo "$up_cmd" > "$SV_DIR/$name/up"
    [ -n "$down_cmd" ] && echo "$down_cmd" > "$SV_DIR/$name/down"
}

create_longrun() {
    local name="$1"
    local run_cmd="$2"
    shift 2
    local deps=("$@")

    mkdir -p "$SV_DIR/$name/dependencies.d"
    echo "longrun" > "$SV_DIR/$name/type"
    cat > "$SV_DIR/$name/run" << RUNEOF
#!/bin/execlineb -P
fdmove -c 2 1
$run_cmd
RUNEOF
    chmod +x "$SV_DIR/$name/run"

    for dep in "${deps[@]}"; do
        touch "$SV_DIR/$name/dependencies.d/$dep"
    done
}

create_oneshot "mount-filesystems" \
    "mount -a && mount -o remount,rw /"

create_longrun "syslogd" "syslogd -n"
create_longrun "eudevd" "udevd --daemon" "mount-filesystems"
create_longrun "seatd" "seatd -g seat" "eudevd"
create_longrun "dbus" "dbus-daemon --system --nofork" "eudevd"
create_longrun "dhcpcd" "dhcpcd -B -q eth0" "eudevd"

# Getty on tty1 and tty2
for tty in tty1 tty2; do
    mkdir -p "$SV_DIR/$tty/dependencies.d"
    echo "longrun" > "$SV_DIR/$tty/type"
    cat > "$SV_DIR/$tty/run" << TTYEOF
#!/bin/execlineb -P
fdmove -c 2 1
/sbin/agetty $tty linux
TTYEOF
    chmod +x "$SV_DIR/$tty/run"
    touch "$SV_DIR/$tty/dependencies.d/mount-filesystems"
done

# ──────────────────────────────────────────────
# First-setup wizard (runs once on first boot)
# ──────────────────────────────────────────────
echo "[*] Installing first-setup wizard..."
SCRIPTS_DIR="$MUSLINX_ROOT/scripts"

# Install the first-setup script
mkdir -p "$SYSROOT/usr/lib/muslinx"
cp "$SCRIPTS_DIR/first-setup.sh" "$SYSROOT/usr/lib/muslinx/first-setup.sh"
chmod +x "$SYSROOT/usr/lib/muslinx/first-setup.sh"

# Create the setup-done marker directory
mkdir -p "$SYSROOT/var/lib/muslinx"

# Create s6 oneshot service for first-setup
create_oneshot "first-setup" \
    "/usr/lib/muslinx/first-setup.sh"

# Add first-setup dependency to tty1 (runs before login prompt)
touch "$SV_DIR/tty1/dependencies.d/first-setup"

# Hook into .profile to trigger first-setup before Sway starts
cat > "$SYSROOT/home/muslinx/.profile" << 'EOF'
# Muslinx First Setup — runs once on first login
if [ ! -f /var/lib/muslinx/.setup-done ]; then
    /usr/lib/muslinx/first-setup.sh
fi

# Auto-start Sway on tty1
if [ "$(tty)" = "/dev/tty1" ] && [ -z "$WAYLAND_DISPLAY" ]; then
    export XDG_SESSION_TYPE=wayland
    export XDG_CURRENT_DESKTOP=sway
    export MOZ_ENABLE_WAYLAND=1
    export QT_QPA_PLATFORM=wayland
    exec sway
fi
EOF

# ──────────────────────────────────────────────
# /etc/os-release
# ──────────────────────────────────────────────
echo "[*] Creating os-release..."
cat > "$SYSROOT/etc/os-release" << 'EOF'
NAME="Muslinx"
VERSION="1.0"
ID=muslinx
VERSION_ID=1.0
PRETTY_NAME="Muslinx Linux 1.0"
HOME_URL="https://muslinx.org"
BUG_REPORT_URL="https://github.com/muslinx/muslinx/issues"
LOGO=muslinx-logo
EOF

# ──────────────────────────────────────────────
# /etc/shells
# ──────────────────────────────────────────────
cat > "$SYSROOT/etc/shells" << 'EOF'
/bin/sh
/bin/bash
/bin/zsh
EOF

# Set ownership (simulated — real chown needs chroot or fakeroot)
echo "[*] Note: File ownership will be set correctly during ISO creation with fakeroot"

echo ""
echo "═══════════════════════════════════════════"
echo "  System configuration complete!"
echo "═══════════════════════════════════════════"
