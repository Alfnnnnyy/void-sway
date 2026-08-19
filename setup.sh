#!/bin/sh

set -eu

echo "========================================"
echo " Void Linux Sway Setup (Optimized)"
echo " Toshiba Satellite P755"
echo "========================================"

if [ "$(id -u)" -ne 0 ]; then
    echo "Jalankan script dengan: sudo sh setup.sh"
    exit 1
fi

USERNAME="${SUDO_USER:-}"

if [ -z "$USERNAME" ]; then
    echo "Gagal mendeteksi user reguler. Jalankan dengan sudo."
    exit 1
fi

USER_HOME="$(getent passwd "$USERNAME" | cut -d: -f6)"
USER_GID="$(id -g "$USERNAME")"

echo
echo "[1/9] Sinkronisasi repositori & update..."
# XBPS meng-update dirinya sendiri dalam transaksi terpisah. Gunakan flag -y
# agar tidak tertahan menunggu konfirmasi interaktif.
xbps-install -Syu -y
xbps-install -Syu -y

echo
echo "[2/9] Instalasi paket pendukung..."
# Gunakan -Sy -y agar repodata tersinkronisasi dan instalasi berjalan non-interaktif.
# Catatan penamaan paket XBPS (case-sensitive): Waybar, Thunar, NetworkManager.
xbps-install -Sy -y \
    sway \
    swaybg \
    swaylock \
    swayidle \
    Waybar \
    foot \
    fuzzel \
    mako \
    Thunar \
    pipewire \
    wireplumber \
    pavucontrol \
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
    brightnessctl \
    grim \
    slurp \
    wl-clipboard \
    gvfs \
    zramen \
    tlp

echo
echo "[3/9] Mengaktifkan runit services..."
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
echo "[4/9] Konfigurasi grup user..."
for GROUP in _seatd audio video input network; do
    if getent group "$GROUP" >/dev/null 2>&1; then
        usermod -aG "$GROUP" "$USERNAME"
        echo "User $USERNAME ditambahkan ke grup: $GROUP"
    fi
done

echo
echo "[5/9] Membuat struktur direktori konfigurasi..."
mkdir -p "$USER_HOME/.config/sway"
mkdir -p "$USER_HOME/.config/waybar"
mkdir -p "$USER_HOME/.config/fuzzel"
mkdir -p "$USER_HOME/.config/mako"
mkdir -p "$USER_HOME/.config/pipewire/pipewire.conf.d"
mkdir -p "$USER_HOME/Pictures"

echo
echo "[6/9] Konfigurasi PipeWire..."
WIREPLUMBER_CONF="/usr/share/examples/wireplumber/10-wireplumber.conf"
PIPEWIRE_PULSE_CONF="/usr/share/examples/pipewire/20-pipewire-pulse.conf"

if [ -f "$WIREPLUMBER_CONF" ]; then
    ln -sf "$WIREPLUMBER_CONF" "$USER_HOME/.config/pipewire/pipewire.conf.d/10-wireplumber.conf"
elif [ -f "/usr/share/wireplumber/wireplumber.conf" ]; then
    ln -sf "/usr/share/wireplumber/wireplumber.conf" "$USER_HOME/.config/pipewire/pipewire.conf.d/10-wireplumber.conf"
fi

if [ -f "$PIPEWIRE_PULSE_CONF" ]; then
    ln -sf "$PIPEWIRE_PULSE_CONF" "$USER_HOME/.config/pipewire/pipewire.conf.d/20-pipewire-pulse.conf"
elif [ -f "/usr/share/pipewire/pipewire-pulse.conf" ]; then
    ln -sf "/usr/share/pipewire/pipewire-pulse.conf" "$USER_HOME/.config/pipewire/pipewire.conf.d/20-pipewire-pulse.conf"
fi

echo
echo "[7/9] Menulis file konfigurasi UI..."

# Sway Config
SWAY_CONFIG="$USER_HOME/.config/sway/config"
if [ ! -f "$SWAY_CONFIG" ]; then
cat > "$SWAY_CONFIG" <<'EOF'
### Toshiba P755 Sway Configuration

set $mod Mod4
font pango:DejaVu Sans 10
floating_modifier $mod normal

# Autostart Services
exec dbus-update-activation-environment --all
exec /usr/libexec/polkit-gnome-authentication-agent-1

# PipeWire: cukup jalankan "pipewire" saja. WirePlumber (session manager)
# dan pipewire-pulse (interface PulseAudio) sudah otomatis di-spawn oleh
# PipeWire lewat symlink di ~/.config/pipewire/pipewire.conf.d/ yang
# dibuat script setup ini. Menjalankan "exec wireplumber" terpisah di sini
# akan membuat WirePlumber start dua kali dan bisa bikin audio tidak stabil.
exec pipewire

exec waybar
exec mako

# Wallpaper (Ganti jika sudah ada file wallpaper)
output * bg ~/Pictures/wallpaper.jpg fill #1a1a1a

# Idle & Lock Management
exec swayidle -w \
    timeout 300 'swaylock -f -c 000000' \
    timeout 600 'swaymsg "output * power off"' \
    resume 'swaymsg "output * power on"' \
    before-sleep 'swaylock -f -c 000000'

# Keybindings - Launchers & Tools
bindsym $mod+Return exec foot
bindsym $mod+d exec fuzzel
bindsym $mod+e exec thunar
bindsym $mod+l exec swaylock -f -c 000000
bindsym $mod+Shift+q kill
bindsym $mod+Shift+c reload
bindsym $mod+Shift+e exec swaymsg exit

# Navigation & Focus
bindsym $mod+Left focus left
bindsym $mod+Down focus down
bindsym $mod+Up focus up
bindsym $mod+Right focus right

bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Down move down
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Right move right

# Layout Management
bindsym $mod+b splith
bindsym $mod+v splitv
bindsym $mod+f fullscreen toggle
bindsym $mod+Shift+space floating toggle

# Workspaces
bindsym $mod+1 workspace number 1
bindsym $mod+2 workspace number 2
bindsym $mod+3 workspace number 3
bindsym $mod+4 workspace number 4
bindsym $mod+5 workspace number 5

bindsym $mod+Shift+1 move container to workspace number 1
bindsym $mod+Shift+2 move container to workspace number 2
bindsym $mod+Shift+3 move container to workspace number 3
bindsym $mod+Shift+4 move container to workspace number 4
bindsym $mod+Shift+5 move container to workspace number 5

# Function Keys (Brightness, Volume, Screenshot)
bindsym XF86MonBrightnessUp exec brightnessctl set +5%
bindsym XF86MonBrightnessDown exec brightnessctl set 5%-

bindsym XF86AudioRaiseVolume exec wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+
bindsym XF86AudioLowerVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindsym XF86AudioMute exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle

bindsym Print exec grim ~/Pictures/screenshot-$(date +%Y-%m-%d_%H-%M-%S).png
bindsym Shift+Print exec slurp | grim -g - ~/Pictures/screenshot-$(date +%Y-%m-%d_%H-%M-%S).png
EOF
fi

# Waybar Config
WAYBAR_CONFIG="$USER_HOME/.config/waybar/config.jsonc"
if [ ! -f "$WAYBAR_CONFIG" ]; then
cat > "$WAYBAR_CONFIG" <<'EOF'
{
    "position": "top",
    "height": 28,
    "modules-left": ["sway/workspaces"],
    "modules-center": ["clock"],
    "modules-right": ["pulseaudio", "network", "battery", "cpu", "memory"]
}
EOF
fi

# Waybar Style
WAYBAR_STYLE="$USER_HOME/.config/waybar/style.css"
if [ ! -f "$WAYBAR_STYLE" ]; then
cat > "$WAYBAR_STYLE" <<'EOF'
* {
    font-family: DejaVu Sans;
    font-size: 12px;
}
window#waybar {
    background: rgba(30, 30, 30, 0.95);
    color: #ffffff;
}
#workspaces button {
    padding: 0 5px;
    color: #888888;
}
#workspaces button.focused {
    color: #ffffff;
    background-color: #444444;
}
#clock, #network, #pulseaudio, #battery, #cpu, #memory {
    padding: 0 10px;
}
EOF
fi

# Fuzzel Config
FUZZEL_CONFIG="$USER_HOME/.config/fuzzel/fuzzel.ini"
if [ ! -f "$FUZZEL_CONFIG" ]; then
cat > "$FUZZEL_CONFIG" <<'EOF'
[main]
font=DejaVu Sans:size=10
terminal=foot
prompt="Run: "
EOF
fi

# Mako Config
MAKO_CONFIG="$USER_HOME/.config/mako/config"
if [ ! -f "$MAKO_CONFIG" ]; then
cat > "$MAKO_CONFIG" <<'EOF'
font=DejaVu Sans 10
background-color=#202020
text-color=#ffffff
border-size=1
border-color=#444444
border-radius=5
default-timeout=5000
EOF
fi

echo
echo "[8/9] Konfigurasi autostart login TTY1..."
BASH_PROFILE="$USER_HOME/.bash_profile"

if [ ! -f "$BASH_PROFILE" ]; then
    touch "$BASH_PROFILE"
fi

if ! grep -q "sway" "$BASH_PROFILE"; then
cat >> "$BASH_PROFILE" <<'EOF'

# Dynamic XDG_RUNTIME_DIR fallback for non-systemd init
if [ -z "$XDG_RUNTIME_DIR" ]; then
    export XDG_RUNTIME_DIR="/tmp/runtime-${USER}"
    if [ ! -d "$XDG_RUNTIME_DIR" ]; then
        mkdir -pm 0700 "$XDG_RUNTIME_DIR"
    fi
    chmod 0700 "$XDG_RUNTIME_DIR"
fi

# Auto-start Sway on TTY1
if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec dbus-run-session sway
fi
EOF
fi

echo
echo "[9/9] Memperbaiki file permissions..."
chown -hR "$USERNAME:$USER_GID" "$USER_HOME/.config" "$USER_HOME/.bash_profile" "$USER_HOME/Pictures"

echo
echo "========================================"
echo " Setup Selesai!"
echo " Silakan reboot sistem Anda: sudo reboot"
echo "========================================"
