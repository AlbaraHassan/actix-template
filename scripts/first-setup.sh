#!/bin/sh
# Muslinx Linux — First Setup Wizard
# Runs on first boot to configure language, timezone, keyboard, user account,
# network, and appearance. Uses dialog for TUI interface.
#
# Triggered by: /etc/s6/sv/first-setup service (oneshot)
# Marker file: /var/lib/muslinx/.setup-done

set -eu

MARKER="/var/lib/muslinx/.setup-done"
SETUP_LOG="/var/log/muslinx-setup.log"

# ──────────────────────────────────────────────
# Skip if already completed
# ──────────────────────────────────────────────
if [ -f "$MARKER" ]; then
    exit 0
fi

# ──────────────────────────────────────────────
# Colors & branding
# ──────────────────────────────────────────────
C_RESET="\033[0m"
C_TURQ="\033[36m"
C_GOLD="\033[33m"
C_ROSE="\033[31m"
C_IVORY="\033[97m"
C_DIM="\033[2m"
C_BOLD="\033[1m"

log() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) $*" >> "$SETUP_LOG"; }

# Determine TUI backend
if command -v dialog >/dev/null 2>&1; then
    TUI="dialog"
elif command -v whiptail >/dev/null 2>&1; then
    TUI="whiptail"
else
    # Fallback: plain text prompts
    TUI="plain"
fi

# ──────────────────────────────────────────────
# Dialog theming
# ──────────────────────────────────────────────
export DIALOGRC=""
if [ "$TUI" = "dialog" ]; then
    DIALOGRC_FILE="/tmp/.muslinx-dialogrc"
    cat > "$DIALOGRC_FILE" << 'RCEOF'
# Muslinx dialog theme
screen_color = (CYAN,BLACK,ON)
shadow_color = (BLACK,BLACK,OFF)
dialog_color = (WHITE,BLACK,OFF)
title_color = (CYAN,BLACK,ON)
border_color = (CYAN,BLACK,ON)
button_active_color = (BLACK,CYAN,ON)
button_inactive_color = (WHITE,BLACK,OFF)
button_key_active_color = (BLACK,CYAN,ON)
button_key_inactive_color = (CYAN,BLACK,ON)
button_label_active_color = (BLACK,CYAN,ON)
button_label_inactive_color = (WHITE,BLACK,OFF)
inputbox_color = (WHITE,BLACK,OFF)
inputbox_border_color = (CYAN,BLACK,ON)
searchbox_color = (WHITE,BLACK,OFF)
searchbox_title_color = (CYAN,BLACK,ON)
searchbox_border_color = (CYAN,BLACK,ON)
position_indicator_color = (YELLOW,BLACK,ON)
menubox_color = (WHITE,BLACK,OFF)
menubox_border_color = (CYAN,BLACK,ON)
item_color = (WHITE,BLACK,OFF)
item_selected_color = (BLACK,CYAN,ON)
tag_color = (CYAN,BLACK,ON)
tag_selected_color = (BLACK,CYAN,ON)
tag_key_color = (YELLOW,BLACK,ON)
tag_key_selected_color = (BLACK,CYAN,ON)
check_color = (WHITE,BLACK,OFF)
check_selected_color = (BLACK,CYAN,ON)
uarrow_color = (CYAN,BLACK,ON)
darrow_color = (CYAN,BLACK,ON)
RCEOF
    export DIALOGRC="$DIALOGRC_FILE"
fi

# ──────────────────────────────────────────────
# Helper functions
# ──────────────────────────────────────────────
COLS=$(tput cols 2>/dev/null || echo 80)
ROWS=$(tput lines 2>/dev/null || echo 24)
DLG_H=$((ROWS - 4))
DLG_W=$((COLS - 8))
[ "$DLG_H" -gt 30 ] && DLG_H=30
[ "$DLG_W" -gt 76 ] && DLG_W=76
LIST_H=$((DLG_H - 8))

dlg_msg() {
    local title="$1"
    local msg="$2"
    if [ "$TUI" = "dialog" ]; then
        dialog --title "$title" --msgbox "$msg" "$DLG_H" "$DLG_W"
    elif [ "$TUI" = "whiptail" ]; then
        whiptail --title "$title" --msgbox "$msg" "$DLG_H" "$DLG_W"
    else
        printf "\n${C_BOLD}${C_TURQ}═══ %s ═══${C_RESET}\n\n%s\n\n" "$title" "$msg"
        printf "${C_DIM}Press Enter to continue...${C_RESET}"
        read -r _
    fi
}

dlg_menu() {
    local title="$1"
    local msg="$2"
    shift 2
    local result=""
    if [ "$TUI" = "dialog" ]; then
        result=$(dialog --title "$title" --menu "$msg" "$DLG_H" "$DLG_W" "$LIST_H" "$@" 3>&1 1>&2 2>&3) || true
    elif [ "$TUI" = "whiptail" ]; then
        result=$(whiptail --title "$title" --menu "$msg" "$DLG_H" "$DLG_W" "$LIST_H" "$@" 3>&1 1>&2 2>&3) || true
    else
        printf "\n${C_BOLD}${C_TURQ}═══ %s ═══${C_RESET}\n\n%s\n\n" "$title" "$msg"
        while [ $# -ge 2 ]; do
            printf "  ${C_TURQ}%-12s${C_RESET} %s\n" "$1" "$2"
            shift 2
        done
        printf "\n${C_GOLD}Enter choice:${C_RESET} "
        read -r result
    fi
    echo "$result"
}

dlg_input() {
    local title="$1"
    local msg="$2"
    local default="${3:-}"
    local result=""
    if [ "$TUI" = "dialog" ]; then
        result=$(dialog --title "$title" --inputbox "$msg" "$DLG_H" "$DLG_W" "$default" 3>&1 1>&2 2>&3) || true
    elif [ "$TUI" = "whiptail" ]; then
        result=$(whiptail --title "$title" --inputbox "$msg" "$DLG_H" "$DLG_W" "$default" 3>&1 1>&2 2>&3) || true
    else
        printf "\n${C_BOLD}${C_TURQ}═══ %s ═══${C_RESET}\n\n%s\n" "$title" "$msg"
        [ -n "$default" ] && printf "${C_DIM}[default: %s]${C_RESET}\n" "$default"
        printf "${C_GOLD}> ${C_RESET}"
        read -r result
        [ -z "$result" ] && result="$default"
    fi
    echo "$result"
}

dlg_password() {
    local title="$1"
    local msg="$2"
    local result=""
    if [ "$TUI" = "dialog" ]; then
        result=$(dialog --title "$title" --insecure --passwordbox "$msg" "$DLG_H" "$DLG_W" 3>&1 1>&2 2>&3) || true
    elif [ "$TUI" = "whiptail" ]; then
        result=$(whiptail --title "$title" --passwordbox "$msg" "$DLG_H" "$DLG_W" 3>&1 1>&2 2>&3) || true
    else
        printf "\n${C_BOLD}${C_TURQ}═══ %s ═══${C_RESET}\n\n%s\n" "$title" "$msg"
        printf "${C_GOLD}Password: ${C_RESET}"
        stty -echo 2>/dev/null || true
        read -r result
        stty echo 2>/dev/null || true
        echo ""
    fi
    echo "$result"
}

dlg_yesno() {
    local title="$1"
    local msg="$2"
    if [ "$TUI" = "dialog" ]; then
        dialog --title "$title" --yesno "$msg" "$DLG_H" "$DLG_W"
        return $?
    elif [ "$TUI" = "whiptail" ]; then
        whiptail --title "$title" --yesno "$msg" "$DLG_H" "$DLG_W"
        return $?
    else
        printf "\n${C_BOLD}${C_TURQ}═══ %s ═══${C_RESET}\n\n%s\n\n" "$title" "$msg"
        printf "${C_GOLD}[y/n]:${C_RESET} "
        read -r yn
        case "$yn" in [yY]*) return 0 ;; *) return 1 ;; esac
    fi
}

# ──────────────────────────────────────────────
# Collected settings
# ──────────────────────────────────────────────
SETUP_LANG="en_US.UTF-8"
SETUP_TZ="UTC"
SETUP_KB="us"
SETUP_DISPLAY_NAME=""
SETUP_USERNAME=""
SETUP_PASSWORD=""
SETUP_HOSTNAME="muslinx"
SETUP_AUTOLOGIN="no"
SETUP_ACCENT="turquoise"

# ══════════════════════════════════════════════
# STEP 1: Welcome
# ══════════════════════════════════════════════
step_welcome() {
    dlg_msg "✦ Welcome to Muslinx" "\
          ✦  M U S L I N X  ✦
       ━━━━━━━━━━━━━━━━━━━━━
         musl · linux · craft


  Welcome to Muslinx Linux!

  This setup wizard will help you configure
  your system. It only takes a few minutes.

  We'll walk you through:

    1. Language & locale
    2. Timezone
    3. Keyboard layout
    4. User account creation
    5. Network setup
    6. Appearance preferences

  Press OK to begin."
    log "Setup wizard started"
}

# ══════════════════════════════════════════════
# STEP 2: Language
# ══════════════════════════════════════════════
step_language() {
    SETUP_LANG=$(dlg_menu "✦ Language & Locale" \
        "Select your preferred language:" \
        "en_US.UTF-8"  "English (United States)" \
        "en_GB.UTF-8"  "English (United Kingdom)" \
        "ar_SA.UTF-8"  "العربية (Arabic)" \
        "fr_FR.UTF-8"  "Français (French)" \
        "de_DE.UTF-8"  "Deutsch (German)" \
        "es_ES.UTF-8"  "Español (Spanish)" \
        "tr_TR.UTF-8"  "Türkçe (Turkish)" \
        "ja_JP.UTF-8"  "日本語 (Japanese)" \
        "zh_CN.UTF-8"  "中文 (Chinese Simplified)" \
        "id_ID.UTF-8"  "Bahasa Indonesia" \
        "pt_BR.UTF-8"  "Português (Brazil)" \
        "ru_RU.UTF-8"  "Русский (Russian)" \
        "ko_KR.UTF-8"  "한국어 (Korean)" \
        "ms_MY.UTF-8"  "Bahasa Melayu (Malay)" \
        "ur_PK.UTF-8"  "اردو (Urdu)" \
        "fa_IR.UTF-8"  "فارسی (Persian)")

    [ -z "$SETUP_LANG" ] && SETUP_LANG="en_US.UTF-8"
    log "Language selected: $SETUP_LANG"
}

# ══════════════════════════════════════════════
# STEP 3: Timezone
# ══════════════════════════════════════════════
step_timezone() {
    local region
    region=$(dlg_menu "✦ Timezone — Region" \
        "Select your region:" \
        "Americas"  "North & South America" \
        "Europe"    "Europe" \
        "Asia"      "Asia & Middle East" \
        "Africa"    "Africa" \
        "Oceania"   "Australia & Pacific")

    [ -z "$region" ] && region="Americas"

    case "$region" in
        Americas)
            SETUP_TZ=$(dlg_menu "✦ Timezone — $region" \
                "Select your city:" \
                "America/New_York"      "New York (EST/EDT)" \
                "America/Chicago"       "Chicago (CST/CDT)" \
                "America/Denver"        "Denver (MST/MDT)" \
                "America/Los_Angeles"   "Los Angeles (PST/PDT)" \
                "America/Toronto"       "Toronto (EST/EDT)" \
                "America/Sao_Paulo"     "São Paulo (BRT)" \
                "America/Mexico_City"   "Mexico City (CST)" \
                "America/Argentina/Buenos_Aires" "Buenos Aires (ART)")
            ;;
        Europe)
            SETUP_TZ=$(dlg_menu "✦ Timezone — $region" \
                "Select your city:" \
                "Europe/London"    "London (GMT/BST)" \
                "Europe/Paris"     "Paris (CET/CEST)" \
                "Europe/Berlin"    "Berlin (CET/CEST)" \
                "Europe/Istanbul"  "Istanbul (TRT)" \
                "Europe/Moscow"    "Moscow (MSK)" \
                "Europe/Madrid"    "Madrid (CET/CEST)" \
                "Europe/Rome"      "Rome (CET/CEST)" \
                "Europe/Amsterdam" "Amsterdam (CET/CEST)")
            ;;
        Asia)
            SETUP_TZ=$(dlg_menu "✦ Timezone — $region" \
                "Select your city:" \
                "Asia/Dubai"       "Dubai (GST)" \
                "Asia/Riyadh"      "Riyadh (AST)" \
                "Asia/Karachi"     "Karachi (PKT)" \
                "Asia/Kolkata"     "Kolkata (IST)" \
                "Asia/Jakarta"     "Jakarta (WIB)" \
                "Asia/Shanghai"    "Shanghai (CST)" \
                "Asia/Tokyo"       "Tokyo (JST)" \
                "Asia/Seoul"       "Seoul (KST)" \
                "Asia/Kuala_Lumpur" "Kuala Lumpur (MYT)")
            ;;
        Africa)
            SETUP_TZ=$(dlg_menu "✦ Timezone — $region" \
                "Select your city:" \
                "Africa/Cairo"         "Cairo (EET)" \
                "Africa/Lagos"         "Lagos (WAT)" \
                "Africa/Nairobi"       "Nairobi (EAT)" \
                "Africa/Johannesburg"  "Johannesburg (SAST)" \
                "Africa/Casablanca"    "Casablanca (WET)")
            ;;
        Oceania)
            SETUP_TZ=$(dlg_menu "✦ Timezone — $region" \
                "Select your city:" \
                "Australia/Sydney"     "Sydney (AEST)" \
                "Australia/Melbourne"  "Melbourne (AEST)" \
                "Australia/Perth"      "Perth (AWST)" \
                "Pacific/Auckland"     "Auckland (NZST)")
            ;;
    esac

    [ -z "$SETUP_TZ" ] && SETUP_TZ="UTC"
    log "Timezone selected: $SETUP_TZ"
}

# ══════════════════════════════════════════════
# STEP 4: Keyboard Layout
# ══════════════════════════════════════════════
step_keyboard() {
    SETUP_KB=$(dlg_menu "✦ Keyboard Layout" \
        "Select your keyboard layout:" \
        "us"     "US English (QWERTY)" \
        "gb"     "UK English (QWERTY)" \
        "ara"    "Arabic" \
        "fr"     "French (AZERTY)" \
        "de"     "German (QWERTZ)" \
        "es"     "Spanish" \
        "tr"     "Turkish (Q)" \
        "jp"     "Japanese" \
        "kr"     "Korean" \
        "latam"  "Latin American" \
        "ru"     "Russian" \
        "in"     "Indian")

    [ -z "$SETUP_KB" ] && SETUP_KB="us"
    log "Keyboard layout selected: $SETUP_KB"
}

# ══════════════════════════════════════════════
# STEP 5: User Account
# ══════════════════════════════════════════════
step_account() {
    # Display Name
    SETUP_DISPLAY_NAME=$(dlg_input "✦ Create Your Account" \
        "Enter your display name:" \
        "Muslinx User")
    [ -z "$SETUP_DISPLAY_NAME" ] && SETUP_DISPLAY_NAME="Muslinx User"

    # Username
    SETUP_USERNAME=$(dlg_input "✦ Create Your Account" \
        "Choose a username (lowercase, no spaces):" \
        "muslinx")
    # Sanitize: lowercase, remove spaces and special chars
    SETUP_USERNAME=$(echo "$SETUP_USERNAME" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-')
    [ -z "$SETUP_USERNAME" ] && SETUP_USERNAME="muslinx"

    # Password
    while true; do
        SETUP_PASSWORD=$(dlg_password "✦ Create Your Account" \
            "Set a password for $SETUP_USERNAME:")

        if [ -z "$SETUP_PASSWORD" ]; then
            dlg_msg "✦ Password Required" "Password cannot be empty. Please try again."
            continue
        fi

        local confirm
        confirm=$(dlg_password "✦ Create Your Account" \
            "Confirm your password:")

        if [ "$SETUP_PASSWORD" = "$confirm" ]; then
            break
        else
            dlg_msg "✦ Password Mismatch" "Passwords did not match. Please try again."
        fi
    done

    # Hostname
    SETUP_HOSTNAME=$(dlg_input "✦ Computer Name" \
        "Choose a name for this computer:" \
        "muslinx")
    SETUP_HOSTNAME=$(echo "$SETUP_HOSTNAME" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')
    [ -z "$SETUP_HOSTNAME" ] && SETUP_HOSTNAME="muslinx"

    # Auto-login
    if dlg_yesno "✦ Automatic Login" \
        "Would you like to log in automatically?\n\n(You can change this later in settings)"; then
        SETUP_AUTOLOGIN="yes"
    else
        SETUP_AUTOLOGIN="no"
    fi

    log "Account created: $SETUP_USERNAME ($SETUP_DISPLAY_NAME) on $SETUP_HOSTNAME"
}

# ══════════════════════════════════════════════
# STEP 6: Network
# ══════════════════════════════════════════════
step_network() {
    # Check if already connected
    if ip route show default 2>/dev/null | grep -q "default"; then
        dlg_msg "✦ Network" \
            "You're already connected!\n\nNetwork connection detected.\nYou can configure WiFi later in settings."
        log "Network: already connected"
        return
    fi

    # Check for WiFi interface
    local wifi_iface=""
    for iface in /sys/class/net/wl*; do
        if [ -e "$iface" ]; then
            wifi_iface=$(basename "$iface")
            break
        fi
    done

    if [ -z "$wifi_iface" ]; then
        dlg_msg "✦ Network" \
            "No WiFi adapter detected.\n\nPlug in an Ethernet cable for network access,\nor configure WiFi later in settings."
        log "Network: no WiFi adapter found"
        return
    fi

    # Scan for networks
    local networks=""
    if command -v wpa_cli >/dev/null 2>&1; then
        dlg_msg "✦ Network" "Scanning for WiFi networks..."
        wpa_cli -i "$wifi_iface" scan >/dev/null 2>&1 || true
        sleep 3
        networks=$(wpa_cli -i "$wifi_iface" scan_results 2>/dev/null | tail -n +2 | \
            awk '{print $5, $3}' | sort -t' ' -k2 -rn | head -10)
    fi

    if [ -z "$networks" ]; then
        local choice
        choice=$(dlg_menu "✦ Network" \
            "No networks found. What would you like to do?" \
            "retry"  "Scan again" \
            "manual" "Enter network name manually" \
            "skip"   "Skip — set up later")

        case "$choice" in
            retry)  step_network; return ;;
            manual)
                local ssid
                ssid=$(dlg_input "✦ Network" "Enter WiFi network name (SSID):")
                if [ -n "$ssid" ]; then
                    local psk
                    psk=$(dlg_password "✦ Network" "Enter password for '$ssid':")
                    if [ -n "$psk" ]; then
                        configure_wifi "$wifi_iface" "$ssid" "$psk"
                    fi
                fi
                ;;
            *)
                log "Network: skipped"
                ;;
        esac
        return
    fi

    # Build menu from scan results
    dlg_msg "✦ Network" \
        "WiFi networks found.\nSelect a network to connect.\n\n(You can also skip and configure later)"
    log "Network: scan complete"
}

configure_wifi() {
    local iface="$1" ssid="$2" psk="$3"

    # Create wpa_supplicant config
    mkdir -p /etc/wpa_supplicant
    wpa_passphrase "$ssid" "$psk" > "/etc/wpa_supplicant/wpa_supplicant-${iface}.conf" 2>/dev/null

    # Start connection
    wpa_supplicant -B -i "$iface" -c "/etc/wpa_supplicant/wpa_supplicant-${iface}.conf" 2>/dev/null || true
    dhcpcd "$iface" 2>/dev/null || true

    sleep 3
    if ip route show default 2>/dev/null | grep -q "default"; then
        dlg_msg "✦ Network" "Connected to '$ssid' successfully!"
        log "Network: connected to $ssid"
    else
        dlg_msg "✦ Network" "Could not connect to '$ssid'.\nYou can try again later in settings."
        log "Network: failed to connect to $ssid"
    fi
}

# ══════════════════════════════════════════════
# STEP 7: Appearance
# ══════════════════════════════════════════════
step_appearance() {
    SETUP_ACCENT=$(dlg_menu "✦ Make It Yours" \
        "Choose your accent color:" \
        "turquoise"  "Turquoise — Iznik ceramic (default)" \
        "gold"       "Gold — Calligraphy gilding" \
        "rose"       "Rose — Persian rose" \
        "coral"      "Coral — Sunset warmth" \
        "amethyst"   "Amethyst — Royal purple")

    [ -z "$SETUP_ACCENT" ] && SETUP_ACCENT="turquoise"
    log "Accent color: $SETUP_ACCENT"
}

# ══════════════════════════════════════════════
# Apply all settings
# ══════════════════════════════════════════════
apply_settings() {
    log "Applying settings..."

    # ── Locale ──
    echo "LANG=$SETUP_LANG" > /etc/locale.conf 2>/dev/null || true
    export LANG="$SETUP_LANG"
    log "Applied locale: $SETUP_LANG"

    # ── Timezone ──
    if [ -f "/usr/share/zoneinfo/$SETUP_TZ" ]; then
        ln -sf "/usr/share/zoneinfo/$SETUP_TZ" /etc/localtime
    fi
    echo "$SETUP_TZ" > /etc/timezone 2>/dev/null || true
    log "Applied timezone: $SETUP_TZ"

    # ── Keyboard ──
    # Update Sway config
    local sway_conf="/home/$SETUP_USERNAME/.config/sway/config"
    if [ -f "$sway_conf" ]; then
        sed -i "s/xkb_layout .*/xkb_layout $SETUP_KB/" "$sway_conf" 2>/dev/null || true
    fi
    # System-wide keyboard config
    mkdir -p /etc/X11/xorg.conf.d
    cat > /etc/X11/xorg.conf.d/00-keyboard.conf << KBEOF
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "$SETUP_KB"
EndSection
KBEOF
    log "Applied keyboard: $SETUP_KB"

    # ── User Account ──
    # Remove default user if different
    if [ "$SETUP_USERNAME" != "muslinx" ]; then
        # Update /etc/passwd
        sed -i "s/^muslinx:/$SETUP_USERNAME:/" /etc/passwd 2>/dev/null || true
        sed -i "s|/home/muslinx|/home/$SETUP_USERNAME|" /etc/passwd 2>/dev/null || true
        sed -i "s/^muslinx:/$SETUP_USERNAME:/" /etc/shadow 2>/dev/null || true
        sed -i "s/muslinx/$SETUP_USERNAME/g" /etc/group 2>/dev/null || true

        # Rename home directory
        if [ -d "/home/muslinx" ] && [ ! -d "/home/$SETUP_USERNAME" ]; then
            mv /home/muslinx "/home/$SETUP_USERNAME" 2>/dev/null || true
        fi
    fi

    # Set display name in passwd GECOS field
    sed -i "s|$SETUP_USERNAME:x:\([0-9]*\):\([0-9]*\):[^:]*:|$SETUP_USERNAME:x:\1:\2:$SETUP_DISPLAY_NAME:|" \
        /etc/passwd 2>/dev/null || true

    # Set password
    echo "$SETUP_USERNAME:$SETUP_PASSWORD" | chpasswd 2>/dev/null || true
    log "Applied user account: $SETUP_USERNAME"

    # ── Hostname ──
    echo "$SETUP_HOSTNAME" > /etc/hostname
    cat > /etc/hosts << HOSTSEOF
127.0.0.1   localhost
127.0.1.1   $SETUP_HOSTNAME
::1         localhost ip6-localhost ip6-loopback
HOSTSEOF
    hostname "$SETUP_HOSTNAME" 2>/dev/null || true
    log "Applied hostname: $SETUP_HOSTNAME"

    # ── Auto-login ──
    if [ "$SETUP_AUTOLOGIN" = "yes" ]; then
        # Configure getty for auto-login on tty1
        local tty1_run="/etc/s6/sv/tty1/run"
        if [ -f "$tty1_run" ]; then
            cat > "$tty1_run" << TTYEOF
#!/bin/execlineb -P
fdmove -c 2 1
/sbin/agetty --autologin $SETUP_USERNAME tty1 linux
TTYEOF
            chmod +x "$tty1_run"
        fi
        log "Auto-login enabled for $SETUP_USERNAME"
    fi

    # ── Accent Color ──
    local accent_hex=""
    case "$SETUP_ACCENT" in
        turquoise) accent_hex="#2ec4b6" ;;
        gold)      accent_hex="#d4a853" ;;
        rose)      accent_hex="#e8637a" ;;
        coral)     accent_hex="#f0886c" ;;
        amethyst)  accent_hex="#9b72cf" ;;
    esac

    # Save accent preference
    mkdir -p "/home/$SETUP_USERNAME/.config/muslinx"
    cat > "/home/$SETUP_USERNAME/.config/muslinx/appearance.conf" << ACCEOF
# Muslinx Appearance Settings
accent_color=$SETUP_ACCENT
accent_hex=$accent_hex
theme=dark
ACCEOF

    # Update Sway border colors if non-default
    if [ "$SETUP_ACCENT" != "turquoise" ] && [ -f "/home/$SETUP_USERNAME/.config/sway/config" ]; then
        sed -i "s/#2ec4b6/$accent_hex/g" "/home/$SETUP_USERNAME/.config/sway/config" 2>/dev/null || true
    fi

    # Update Waybar accent if non-default
    if [ "$SETUP_ACCENT" != "turquoise" ] && [ -f "/home/$SETUP_USERNAME/.config/waybar/style.css" ]; then
        sed -i "s/#2ec4b6/$accent_hex/g" "/home/$SETUP_USERNAME/.config/waybar/style.css" 2>/dev/null || true
    fi

    # Fix ownership
    chown -R "$(id -u "$SETUP_USERNAME" 2>/dev/null || echo 1000):$(id -g "$SETUP_USERNAME" 2>/dev/null || echo 1000)" \
        "/home/$SETUP_USERNAME" 2>/dev/null || true

    log "Applied accent color: $SETUP_ACCENT ($accent_hex)"
}

# ══════════════════════════════════════════════
# STEP 8: Summary & Complete
# ══════════════════════════════════════════════
step_summary() {
    local autologin_label="No"
    [ "$SETUP_AUTOLOGIN" = "yes" ] && autologin_label="Yes"

    if dlg_yesno "✦ Setup Summary" "\
Ready to configure your system with these settings:

  ┌─────────────────────────────────────────┐
  │  Language:    $SETUP_LANG
  │  Timezone:    $SETUP_TZ
  │  Keyboard:    $SETUP_KB
  │  User:        $SETUP_DISPLAY_NAME ($SETUP_USERNAME)
  │  Hostname:    $SETUP_HOSTNAME
  │  Auto-login:  $autologin_label
  │  Accent:      $SETUP_ACCENT
  └─────────────────────────────────────────┘

Apply these settings?"; then
        return 0
    else
        return 1
    fi
}

step_complete() {
    dlg_msg "✦ Setup Complete!" "\
     ━━━━━━━━━━━━━━━━━━━━━━━━━━

        ✦  You're all set!  ✦

     ━━━━━━━━━━━━━━━━━━━━━━━━━━

  Welcome to Muslinx, $SETUP_DISPLAY_NAME!

  Your system has been configured and is
  ready to use.

  You can change these settings anytime in
  System Preferences or by editing configs
  in ~/.config/

  The desktop will start momentarily...

     ━━━━━━━━━━━━━━━━━━━━━━━━━━
       musl · linux · craft
     ━━━━━━━━━━━━━━━━━━━━━━━━━━"

    log "Setup complete!"
}

# ══════════════════════════════════════════════
# Main
# ══════════════════════════════════════════════
main() {
    mkdir -p "$(dirname "$MARKER")" "$(dirname "$SETUP_LOG")"

    clear
    log "═══ Muslinx First Setup started ═══"

    step_welcome
    step_language
    step_timezone
    step_keyboard
    step_account
    step_network
    step_appearance

    # Confirm and apply
    if step_summary; then
        apply_settings
        step_complete
    else
        # User cancelled — re-run from beginning
        dlg_msg "✦ Setup" "Setup cancelled. Restarting wizard..."
        main
        return
    fi

    # Mark setup as done
    touch "$MARKER"
    log "Marker file created: $MARKER"

    # Cleanup
    rm -f /tmp/.muslinx-dialogrc
}

main "$@"
