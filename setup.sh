#!/bin/sh

set -eu

echo "========================================"
echo " Void Linux Sway Setup"
echo " Toshiba Satellite P755"
echo "========================================"

if [ "$(id -u)" -ne 0 ]; then
    echo "Jalankan script dengan:"
    echo "sudo sh setup.sh"
    exit 1
fi

USERNAME="${SUDO_USER:-}"

if [ -z "$USERNAME" ]; then
    echo "Tidak dapat menentukan user biasa."
    echo "Jalankan menggunakan sudo, bukan login sebagai root."
    exit 1
fi

USER_HOME="$(getent passwd "$USERNAME" | cut -d: -f6)"

echo
echo "[1/10] Update repository..."
xbps-install -S

echo
echo "[2/10] Install packages..."

xbps-install -y \
    sway \
    swaybg \
    waybar \
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

echo
echo "[3/10] Enabling runit services..."

enable_service() {
    SERVICE="$1"

    if [ -e "/var/service/$SERVICE" ]; then
        echo "Service $SERVICE sudah aktif."
        return
    fi

    if [ -d "/etc/sv/$SERVICE" ]; then
        ln -s "/etc/sv/$SERVICE" "/var/service/$SERVICE"
        echo "Enabled: $SERVICE"
    else
        echo "WARNING: /etc/sv/$SERVICE tidak ditemukan."
    fi
}

enable_service dbus
enable_service NetworkManager
enable_service seatd
enable_service tlp
enable_service zramen

echo
echo "[4/10] Adding user to required groups..."

for GROUP in _seatd audio video network; do
    if getent group "$GROUP" >/dev/null 2>&1; then
        usermod -aG "$GROUP" "$USERNAME"
        echo "Added $USERNAME -> $GROUP"
    else
        echo "WARNING: group $GROUP tidak ditemukan."
    fi
done

echo
echo "[5/10] Creating configuration directories..."

mkdir -p "$USER_HOME/.config/sway"
mkdir -p "$USER_HOME/.config/waybar"
mkdir -p "$USER_HOME/.config/fuzzel"
mkdir -p "$USER_HOME/.config/mako"
mkdir -p "$USER_HOME/.config/pipewire/pipewire.conf.d"
mkdir -p "$USER_HOME/Pictures"

chown -R "$USERNAME":"$(id -gn "$USERNAME")" \
    "$USER_HOME/.config" \
    "$USER_HOME/Pictures"

echo
echo "[6/10] Configuring PipeWire..."

WIREPLUMBER_CONF="/usr/share/examples/wireplumber/10-wireplumber.conf"
PIPEWIRE_PULSE_CONF="/usr/share/examples/pipewire/20-pipewire-pulse.conf"

if [ -f "$WIREPLUMBER_CONF" ]; then
    ln -sf \
        "$WIREPLUMBER_CONF" \
        "$USER_HOME/.config/pipewire/pipewire.conf.d/10-wireplumber.conf"
fi

if [ -f "$PIPEWIRE_PULSE_CONF" ]; then
    ln -sf \
        "$PIPEWIRE_PULSE_CONF" \
        "$USER_HOME/.config/pipewire/pipewire.conf.d/20-pipewire-pulse.conf"
fi

echo
echo "[7/10] Configuring Sway..."

SWAY_CONFIG="$USER_HOME/.config/sway/config"

if [ ! -f "$SWAY_CONFIG" ]; then

cat > "$SWAY_CONFIG" <<'EOF'
### Toshiba P755 Sway Configuration

set $mod Mod4

font pango:DejaVu Sans 10

# Wallpaper
output * bg ~/Pictures/wallpaper.jpg fill

# Applications
exec waybar
exec mako

# Idle / lock
exec swayidle -w \
    timeout 300 'swaylock -f' \
    timeout 600 'swaymsg "output * power off"' \
    resume 'swaymsg "output * power on"' \
    before-sleep 'swaylock -f'

# Terminal
bindsym $mod+Return exec foot

# Application launcher
bindsym $mod+d exec fuzzel

# File manager
bindsym $mod+e exec thunar

# Lock
bindsym $mod+l exec swaylock -f

# Kill window
bindsym $mod+Shift+q kill

# Reload Sway
bindsym $mod+Shift+c reload

# Exit Sway
bindsym $mod+Shift+e exec swaymsg exit

# Brightness
bindsym XF86MonBrightnessUp exec brightnessctl set +5%
bindsym XF86MonBrightnessDown exec brightnessctl set 5%-

# Screenshot
bindsym Print exec grim ~/Pictures/screenshot-$(date +%Y-%m-%d_%H-%M-%S).png
EOF

else
    echo "Sway config sudah ada. Tidak ditimpa."
fi

echo
echo "[8/10] Configuring Waybar..."

WAYBAR_CONFIG="$USER_HOME/.config/waybar/config.jsonc"

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

fi

WAYBAR_STYLE="$USER_HOME/.config/waybar/style.css"

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

fi

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

fi

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

fi

echo
echo "Creating XDG runtime directory..."

USER_UID="$(id -u "$USERNAME")"

mkdir -p "/run/user/$USER_UID"
chown "$USERNAME":"$(id -gn "$USERNAME")" "/run/user/$USER_UID"
chmod 700 "/run/user/$USER_UID"

echo
echo "Configuring automatic Sway startup..."

BASH_PROFILE="$USER_HOME/.bash_profile"

if [ ! -f "$BASH_PROFILE" ]; then
    touch "$BASH_PROFILE"
    chown "$USERNAME":"$(id -gn "$USERNAME")" "$BASH_PROFILE"
fi

if ! grep -q "dbus-run-session sway" "$BASH_PROFILE"; then

cat >> "$BASH_PROFILE" <<'EOF'

# Start Sway automatically on TTY1
if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    exec dbus-run-session sway
fi
EOF

fi

echo
echo "Fixing configuration ownership..."

chown -R "$USERNAME":"$(id -gn "$USERNAME")" \
    "$USER_HOME/.config/sway" \
    "$USER_HOME/.config/waybar" \
    "$USER_HOME/.config/fuzzel" \
    "$USER_HOME/.config/mako" \
    "$USER_HOME/.config/pipewire" \
    "$USER_HOME/.bash_profile"

echo
echo "========================================"
echo " Setup selesai."
echo "========================================"
echo
echo "User      : $USERNAME"
echo "Home      : $USER_HOME"
echo
echo "Services:"
echo "  dbus"
echo "  NetworkManager"
echo "  seatd"
echo "  tlp"
echo "  zramen"
echo
echo "Sway akan otomatis berjalan ketika login"
echo "ke TTY1 setelah reboot."
echo
echo "Reboot:"
echo
echo "    reboot"
echo
echo "Setelah reboot:"
echo "    login -> Sway"
echo
echo "Shortcut:"
echo "    Super + Enter       Foot"
echo "    Super + D           Fuzzel"
echo "    Super + E           Thunar"
echo "    Super + L           Lock"
echo "    Super + Shift + Q   Kill window"
echo "    Super + Shift + C   Reload Sway"
echo "    Super + Shift + E   Exit Sway"
echo
