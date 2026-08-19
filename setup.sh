#!/bin/sh

set -eu

echo "========================================"
echo " Void Linux Sway Setup"
echo " Toshiba Satellite P755"
echo "========================================"

# ============================================================
# ROOT CHECK
# ============================================================

if [ "$(id -u)" -ne 0 ]; then
    echo
    echo "ERROR: Script harus dijalankan sebagai root."
    echo
    echo "Gunakan:"
    echo "  sudo ./setup.sh"
    echo
    exit 1
fi

# ============================================================
# DETECT NORMAL USER
# ============================================================

USERNAME="${SUDO_USER:-}"

# Kalau dijalankan langsung dari root shell,
# cari user biasa dari /home.
if [ -z "$USERNAME" ] || [ "$USERNAME" = "root" ]; then

    if [ -d /home ]; then
        for DIR in /home/*; do
            if [ -d "$DIR" ]; then
                USERNAME="$(basename "$DIR")"
                break
            fi
        done
    fi
fi

if [ -z "${USERNAME:-}" ] || [ "$USERNAME" = "root" ]; then
    echo
    echo "ERROR: Tidak dapat menentukan user biasa."
    echo
    echo "User biasa harus mempunyai home directory seperti:"
    echo "  /home/username"
    echo
    echo "Buat user biasa terlebih dahulu."
    exit 1
fi

USER_HOME="$(getent passwd "$USERNAME" | cut -d: -f6)"

if [ -z "$USER_HOME" ] || [ ! -d "$USER_HOME" ]; then
    echo
    echo "ERROR: Home directory user tidak ditemukan."
    echo "User: $USERNAME"
    echo
    exit 1
fi

USER_GROUP="$(id -gn "$USERNAME")"
USER_UID="$(id -u "$USERNAME")"

echo
echo "Detected user : $USERNAME"
echo "Home          : $USER_HOME"
echo "UID           : $USER_UID"
echo "Group         : $USER_GROUP"
echo

# ============================================================
# UPDATE REPOSITORY
# ============================================================

echo "[1/10] Updating repository..."

xbps-install -S

# ============================================================
# INSTALL PACKAGES
# ============================================================

echo
echo "[2/10] Installing packages..."

xbps-install -y \
    sway \
    swaybg \
    Waybar \
    foot \
    fuzzel \
    mako \
    thunar \
    pipewire \
    wireplumber \
    NetworkManager \
    seatd \
    dbus \
    polkit-gnome \
    mesa-dri \
    mesa-vaapi \
    libva-utils \
    git \
    curl \
    wget \
    dejavu-fonts-ttf \
    swaylock \
    swayidle \
    brightnessctl \
    grim \
    slurp \
    gvfs \
    zramen \
    tlp \
    pavucontrol

# ============================================================
# ENABLE RUNIT SERVICES
# ============================================================

echo
echo "[3/10] Enabling runit services..."

enable_service() {
    SERVICE="$1"

    if [ -e "/var/service/$SERVICE" ]; then
        echo "  [OK] $SERVICE already enabled."
        return 0
    fi

    if [ -d "/etc/sv/$SERVICE" ]; then
        ln -s "/etc/sv/$SERVICE" "/var/service/$SERVICE"
        echo "  [OK] Enabled $SERVICE."
    else
        echo "  [SKIP] /etc/sv/$SERVICE not found."
    fi
}

enable_service dbus
enable_service NetworkManager
enable_service seatd
enable_service tlp
enable_service zramen

# ============================================================
# USER GROUPS
# ============================================================

echo
echo "[4/10] Configuring user groups..."

for GROUP in _seatd audio video network; do

    if getent group "$GROUP" >/dev/null 2>&1; then
        usermod -aG "$GROUP" "$USERNAME"
        echo "  [OK] $USERNAME -> $GROUP"
    else
        echo "  [SKIP] Group $GROUP not found."
    fi

done

# ============================================================
# DIRECTORIES
# ============================================================

echo
echo "[5/10] Creating configuration directories..."

mkdir -p "$USER_HOME/.config/sway"
mkdir -p "$USER_HOME/.config/waybar"
mkdir -p "$USER_HOME/.config/fuzzel"
mkdir -p "$USER_HOME/.config/mako"
mkdir -p "$USER_HOME/.config/pipewire/pipewire.conf.d"
mkdir -p "$USER_HOME/Pictures"

chown "$USERNAME:$USER_GROUP" "$USER_HOME/.config"
chown "$USERNAME:$USER_GROUP" "$USER_HOME/Pictures"

# ============================================================
# PIPEWIRE
# ============================================================

echo
echo "[6/10] Configuring PipeWire..."

WIREPLUMBER_CONF="/usr/share/examples/wireplumber/10-wireplumber.conf"
PIPEWIRE_PULSE_CONF="/usr/share/examples/pipewire/20-pipewire-pulse.conf"

if [ -f "$WIREPLUMBER_CONF" ]; then

    ln -sf \
        "$WIREPLUMBER_CONF" \
        "$USER_HOME/.config/pipewire/pipewire.conf.d/10-wireplumber.conf"

    echo "  [OK] WirePlumber configuration."

else
    echo "  [INFO] WirePlumber example config not found."
fi

if [ -f "$PIPEWIRE_PULSE_CONF" ]; then

    ln -sf \
        "$PIPEWIRE_PULSE_CONF" \
        "$USER_HOME/.config/pipewire/pipewire.conf.d/20-pipewire-pulse.conf"

    echo "  [OK] PipeWire PulseAudio compatibility."

else
    echo "  [INFO] PipeWire PulseAudio config not found."
fi

# ============================================================
# Sway
# ============================================================

echo
echo "[7/10] Configuring Sway..."

SWAY_CONFIG="$USER_HOME/.config/sway/config"

if [ ! -f "$SWAY_CONFIG" ]; then

cat > "$SWAY_CONFIG" <<'EOF'
### Toshiba Satellite P755
### Sway configuration

set $mod Mod4

font pango:DejaVu Sans 10

# Wallpaper
output * bg ~/Pictures/wallpaper.jpg fill

# Applications
exec Waybar
exec mako

# Idle and lock
exec swayidle -w \
    timeout 300 'swaylock -f' \
    timeout 600 'swaymsg "output * power off"' \
    resume 'swaymsg "output * power on"' \
    before-sleep 'swaylock -f'

# Terminal
bindsym $mod+Return exec foot

# Launcher
bindsym $mod+d exec fuzzel

# File manager
bindsym $mod+e exec thunar

# Lock
bindsym $mod+l exec swaylock -f

# Kill window
bindsym $mod+Shift+q kill

# Reload
bindsym $mod+Shift+c reload

# Exit
bindsym $mod+Shift+e exec swaymsg exit

# Brightness
bindsym XF86MonBrightnessUp exec brightnessctl set +5%
bindsym XF86MonBrightnessDown exec brightnessctl set 5%-

# Screenshot
bindsym Print exec sh -c 'grim "$HOME/Pictures/screenshot-$(date +%Y-%m-%d_%H-%M-%S).png"'
EOF

    echo "  [OK] Sway configuration created."

else
    echo "  [SKIP] Sway configuration already exists."
fi

# ============================================================
# WAYBAR
# ============================================================

echo
echo "[8/10] Configuring Waybar..."

WAYBAR_CONFIG="$USER_HOME/.config/waybar/config.jsonc"
WAYBAR_STYLE="$USER_HOME/.config/waybar/style.css"

if [ ! -f "$WAYBAR_CONFIG" ]; then

cat > "$WAYBAR_CONFIG" <<'EOF'
{
    "position": "top",
    "height": 28,

    "modules-left": [
        "sway/workspaces"
    ],

    "modules-center": [
        "clock"
    ],

    "modules-right": [
        "network",
        "pulseaudio",
        "battery",
        "cpu",
        "memory"
    ]
}
EOF

    echo "  [OK] Waybar config created."

else
    echo "  [SKIP] Waybar config already exists."
fi

if [ ! -f "$WAYBAR_STYLE" ]; then

cat > "$WAYBAR_STYLE" <<'EOF'
* {
    font-family: DejaVu Sans;
    font-size: 12px;
}

window#waybar {
    background: rgba(30, 30, 30, 0.95);
}

#clock,
#network,
#pulseaudio,
#battery,
#cpu,
#memory {
    padding: 0 8px;
}
EOF

    echo "  [OK] Waybar style created."

else
    echo "  [SKIP] Waybar style already exists."
fi

# ============================================================
# FUZZEL
# ============================================================

echo
echo "[9/10] Configuring Fuzzel..."

FUZZEL_CONFIG="$USER_HOME/.config/fuzzel/fuzzel.ini"

if [ ! -f "$FUZZEL_CONFIG" ]; then

cat > "$FUZZEL_CONFIG" <<'EOF'
[main]
font=DejaVu Sans:size=10
terminal=foot
prompt=Run:
EOF

    echo "  [OK] Fuzzel configuration created."

else
    echo "  [SKIP] Fuzzel configuration already exists."
fi

# ============================================================
# MAKO
# ============================================================

echo
echo "[10/10] Configuring Mako..."

MAKO_CONFIG="$USER_HOME/.config/mako/config"

if [ ! -f "$MAKO_CONFIG" ]; then

cat > "$MAKO_CONFIG" <<'EOF'
font=DejaVu Sans 10
background-color=#202020
text-color=#ffffff
border-size=1
border-radius=5
default-timeout=5000
EOF

    echo "  [OK] Mako configuration created."

else
    echo "  [SKIP] Mako configuration already exists."
fi

# ============================================================
# XDG RUNTIME DIRECTORY
# ============================================================

echo
echo "Configuring XDG_RUNTIME_DIR..."

RUNTIME_DIR="/run/user/$USER_UID"

mkdir -p "$RUNTIME_DIR"
chown "$USERNAME:$USER_GROUP" "$RUNTIME_DIR"
chmod 700 "$RUNTIME_DIR"

# ============================================================
# BASH PROFILE
# ============================================================

echo
echo "Configuring automatic Sway startup..."

BASH_PROFILE="$USER_HOME/.bash_profile"

if [ ! -f "$BASH_PROFILE" ]; then
    touch "$BASH_PROFILE"
    chown "$USERNAME:$USER_GROUP" "$BASH_PROFILE"
fi

if ! grep -q "dbus-run-session sway" "$BASH_PROFILE"; then

cat >> "$BASH_PROFILE" <<'EOF'

# Void Linux Sway
# Start Sway automatically on TTY1

if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then

    export XDG_RUNTIME_DIR="/run/user/$(id -u)"

    exec dbus-run-session sway

fi
EOF

    echo "  [OK] Automatic Sway startup configured."

else
    echo "  [SKIP] Sway startup already configured."
fi

# ============================================================
# OWNERSHIP
# ============================================================

echo
echo "Fixing configuration ownership..."

chown -R "$USERNAME:$USER_GROUP" \
    "$USER_HOME/.config/sway" \
    "$USER_HOME/.config/waybar" \
    "$USER_HOME/.config/fuzzel" \
    "$USER_HOME/.config/mako" \
    "$USER_HOME/.config/pipewire"

chown "$USERNAME:$USER_GROUP" "$BASH_PROFILE"

# ============================================================
# DONE
# ============================================================

echo
echo "========================================"
echo " Setup selesai!"
echo "========================================"
echo
echo "User : $USERNAME"
echo "Home : $USER_HOME"
echo
echo "Enabled services:"
echo "  dbus"
echo "  NetworkManager"
echo "  seatd"
echo "  tlp"
echo "  zramen"
echo
echo "Sway akan otomatis dijalankan ketika"
echo "login ke TTY1."
echo
echo "Shortcut:"
echo
echo "  Super + Enter       Foot"
echo "  Super + D           Fuzzel"
echo "  Super + E           Thunar"
echo "  Super + L           Lock"
echo "  Super + Shift + Q   Kill window"
echo "  Super + Shift + C   Reload Sway"
echo "  Super + Shift + E   Exit Sway"
echo
echo "Reboot dengan:"
echo
echo "  reboot"
echo
