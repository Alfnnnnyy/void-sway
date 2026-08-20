#!/usr/bin/env bash
set -u

# ============================================================================
# void-sway Uninstaller for ZSpace Migration
# ============================================================================
# Script ini menghapus paket dan konfigurasi dari void-sway
# (https://github.com/Alfnnnnyy/void-sway) yang tidak lagi diperlukan
# setelah migrasi ke ZSpace.
#
# Paket yang TETAP dipertahankan (dibutuhkan ZSpace):
#   NetworkManager, pipewire, wireplumber, seatd, dbus,
#   mesa-dri, mesa-vaapi, git, curl, wget,
#   Waybar, Thunar, pavucontrol, brightnessctl,
#   grim, slurp, wl-clipboard, gvfs
#
# Jalankan SEBELUM atau SESUDAH install ZSpace.
# ============================================================================

# --- Colors ---
if [[ -t 1 ]]; then
    C_RESET='\033[0m'; C_BOLD='\033[1m'
    C_GREEN='\033[32m'; C_YELLOW='\033[33m'
    C_RED='\033[31m'; C_CYAN='\033[36m'; C_DIM='\033[2m'
else
    C_RESET=''; C_BOLD=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_CYAN=''; C_DIM=''
fi

log_ok()   { echo -e "${C_GREEN}[OK]${C_RESET}     $1"; }
log_warn() { echo -e "${C_YELLOW}[WARN]${C_RESET}   $1"; }
log_info() { echo -e "${C_CYAN}[INFO]${C_RESET}   $1"; }
log_skip() { echo -e "${C_DIM}[SKIP]${C_RESET}   $1"; }

step_title() {
    echo ""
    echo -e "${C_BOLD}${C_DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo -e "${C_BOLD}${C_CYAN}$1${C_RESET}"
    echo -e "${C_BOLD}${C_DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
}

ask_yes_no() {
    local answer
    read -r -p "$1 (y/n): " answer
    [[ "$answer" =~ ^[yY]([eE][sS])?$ ]]
}

# ============================================================================
cat << 'EOF'

 _    __      _     __   _____                      
| |  / /___  (_)___/ /  / ___/      ______ _ __  __
| | / / __ \/ / __  /   \__ \ | /| / / __ `/ / / /
| |/ / /_/ / / /_/ /   ___/ / |/ |/ / /_/ / /_/ / 
|___/\____/_/\__,_/   /____/|__/|__/\__,_/\__, /  
                                          /____/   
              >>> UNINSTALLER <<<

EOF

echo -e "${C_BOLD}Void-Sway Uninstaller untuk migrasi ke ZSpace${C_RESET}"
echo "Script ini akan menghapus paket dan konfigurasi void-sway"
echo "yang sudah digantikan oleh ZSpace."
echo ""
echo -e "${C_YELLOW}Pastikan ZSpace sudah terinstall sebelum menjalankan script ini!${C_RESET}"
echo ""

if ! ask_yes_no "===> Lanjutkan proses uninstall void-sway?"; then
    echo "Dibatalkan."
    exit 0
fi

# ============================================================================
# STEP 1: Uninstall paket void-sway yang digantikan ZSpace
# ============================================================================
step_title "1 - UNINSTALL PAKET VOID-SWAY (digantikan ZSpace)"

# Paket yang PASTI digantikan:
#   sway        → hyprland / niri / mangowm / labwc
#   swaybg      → awww
#   swayidle    → hypridle
#   swaylock    → hyprlock
#   foot        → kitty
#   fuzzel      → rofi
#   mako        → swaync
#   polkit-gnome → mate-polkit
#   dejavu-fonts-ttf → font-noto-ttf + font-jetbrains-mono-nerd

REPLACED_PKGS=(
    sway
    swaybg
    swayidle
    swaylock
    foot
    fuzzel
    mako
    polkit-gnome
    dejavu-fonts-ttf
)

echo ""
echo "Paket yang akan dihapus (sudah digantikan ZSpace):"
echo ""
echo "  sway              → hyprland / niri / mangowm / labwc"
echo "  swaybg            → awww (wallpaper daemon)"
echo "  swayidle          → hypridle"
echo "  swaylock          → hyprlock"
echo "  foot              → kitty (terminal)"
echo "  fuzzel            → rofi (launcher)"
echo "  mako              → swaync (notifikasi)"
echo "  polkit-gnome      → mate-polkit"
echo "  dejavu-fonts-ttf  → font-noto-ttf + font-jetbrains-mono-nerd"
echo ""

if ask_yes_no "===> Hapus paket-paket di atas?"; then
    for pkg in "${REPLACED_PKGS[@]}"; do
        if xbps-query "$pkg" >/dev/null 2>&1; then
            if sudo xbps-remove -Ry "$pkg" 2>/dev/null; then
                log_ok "Dihapus: $pkg"
            else
                log_warn "Gagal menghapus: $pkg (mungkin dependensi paket lain)"
            fi
        else
            log_skip "Tidak terinstall: $pkg"
        fi
    done
else
    log_skip "Melewati penghapusan paket utama."
fi

# ============================================================================
# STEP 2: Paket opsional void-sway
# ============================================================================
step_title "2 - PAKET OPSIONAL VOID-SWAY"

echo ""
echo "Paket berikut dipasang oleh void-sway tapi TIDAK digunakan ZSpace."
echo "Anda bisa memilih untuk mempertahankan jika masih membutuhkannya."
echo ""

# --- tlp ---
if xbps-query tlp >/dev/null 2>&1; then
    echo -e "  ${C_BOLD}tlp${C_RESET} — Laptop power management daemon"
    if ask_yes_no "  ===> Hapus tlp?"; then
        # Hapus runit service dulu
        if [ -L "/var/service/tlp" ]; then
            sudo rm -f /var/service/tlp
            log_ok "Runit service tlp dinonaktifkan."
        fi
        sudo xbps-remove -Ry tlp 2>/dev/null && log_ok "Dihapus: tlp" || log_warn "Gagal menghapus tlp"
    else
        log_skip "Mempertahankan: tlp"
    fi
else
    log_skip "tlp tidak terinstall."
fi

# --- zramen ---
if xbps-query zramen >/dev/null 2>&1; then
    echo -e "  ${C_BOLD}zramen${C_RESET} — Zram swap manager"
    if ask_yes_no "  ===> Hapus zramen?"; then
        if [ -L "/var/service/zramen" ]; then
            sudo rm -f /var/service/zramen
            log_ok "Runit service zramen dinonaktifkan."
        fi
        sudo xbps-remove -Ry zramen 2>/dev/null && log_ok "Dihapus: zramen" || log_warn "Gagal menghapus zramen"
    else
        log_skip "Mempertahankan: zramen"
    fi
else
    log_skip "zramen tidak terinstall."
fi

# --- libva-utils ---
if xbps-query libva-utils >/dev/null 2>&1; then
    echo -e "  ${C_BOLD}libva-utils${C_RESET} — VA-API diagnostic tools (vainfo)"
    if ask_yes_no "  ===> Hapus libva-utils?"; then
        sudo xbps-remove -Ry libva-utils 2>/dev/null && log_ok "Dihapus: libva-utils" || log_warn "Gagal menghapus libva-utils"
    else
        log_skip "Mempertahankan: libva-utils"
    fi
else
    log_skip "libva-utils tidak terinstall."
fi

# ============================================================================
# STEP 3: Hapus konfigurasi void-sway
# ============================================================================
step_title "3 - HAPUS KONFIGURASI VOID-SWAY"

echo ""
echo "Konfigurasi void-sway yang akan dihapus:"
echo "  ~/.config/sway/           (sway config)"
echo "  ~/.config/fuzzel/         (fuzzel config)"
echo "  ~/.config/mako/           (mako config)"
echo "  ~/.config/waybar/config.jsonc  (waybar void-sway config)"
echo "  ~/.config/waybar/style.css     (waybar void-sway style)"
echo ""

BACKUP_TS="$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP_DIR="$HOME/Backup_voidsway_$BACKUP_TS"

if ask_yes_no "===> Backup lalu hapus konfigurasi void-sway?"; then
    mkdir -p "$BACKUP_DIR"
    log_info "Backup folder: $BACKUP_DIR"

    # Backup & remove sway config
    if [ -d "$HOME/.config/sway" ]; then
        cp -a "$HOME/.config/sway" "$BACKUP_DIR/sway"
        rm -rf "$HOME/.config/sway"
        log_ok "Dihapus: ~/.config/sway (backup di $BACKUP_DIR/sway)"
    else
        log_skip "~/.config/sway tidak ditemukan."
    fi

    # Backup & remove fuzzel config
    if [ -d "$HOME/.config/fuzzel" ]; then
        cp -a "$HOME/.config/fuzzel" "$BACKUP_DIR/fuzzel"
        rm -rf "$HOME/.config/fuzzel"
        log_ok "Dihapus: ~/.config/fuzzel (backup di $BACKUP_DIR/fuzzel)"
    else
        log_skip "~/.config/fuzzel tidak ditemukan."
    fi

    # Backup & remove mako config
    if [ -d "$HOME/.config/mako" ]; then
        cp -a "$HOME/.config/mako" "$BACKUP_DIR/mako"
        rm -rf "$HOME/.config/mako"
        log_ok "Dihapus: ~/.config/mako (backup di $BACKUP_DIR/mako)"
    else
        log_skip "~/.config/mako tidak ditemukan."
    fi

    # Backup & remove void-sway waybar configs (only the specific files)
    if [ -f "$HOME/.config/waybar/config.jsonc" ]; then
        mkdir -p "$BACKUP_DIR/waybar"
        cp "$HOME/.config/waybar/config.jsonc" "$BACKUP_DIR/waybar/"
        rm -f "$HOME/.config/waybar/config.jsonc"
        log_ok "Dihapus: ~/.config/waybar/config.jsonc"
    else
        log_skip "~/.config/waybar/config.jsonc tidak ditemukan."
    fi

    if [ -f "$HOME/.config/waybar/style.css" ]; then
        mkdir -p "$BACKUP_DIR/waybar"
        cp "$HOME/.config/waybar/style.css" "$BACKUP_DIR/waybar/"
        rm -f "$HOME/.config/waybar/style.css"
        log_ok "Dihapus: ~/.config/waybar/style.css"
    else
        log_skip "~/.config/waybar/style.css tidak ditemukan."
    fi

    log_ok "Backup konfigurasi void-sway selesai."
else
    log_skip "Melewati penghapusan konfigurasi."
fi

# ============================================================================
# STEP 4: Hapus autostart sway dari .profile / .bash_profile
# ============================================================================
step_title "4 - HAPUS AUTOSTART SWAY DARI PROFILE"

echo ""
echo "void-sway menambahkan snippet autostart sway ke:"
echo "  ~/.profile"
echo "  ~/.bash_profile"
echo ""
echo "Snippet yang dihapus: blok XDG_RUNTIME_DIR + 'exec dbus-run-session sway'"
echo ""

if ask_yes_no "===> Hapus autostart sway dari .profile dan .bash_profile?"; then
    for profile_file in "$HOME/.profile" "$HOME/.bash_profile"; do
        if [ -f "$profile_file" ]; then
            if grep -q "dbus-run-session sway" "$profile_file" 2>/dev/null; then
                # Backup
                mkdir -p "$BACKUP_DIR"
                cp "$profile_file" "$BACKUP_DIR/$(basename "$profile_file")"

                # Hapus blok void-sway (dari komentar XDG hingga fi terakhir)
                sed -i '/^# Dynamic XDG_RUNTIME_DIR fallback/,/^fi$/d' "$profile_file"
                # Hapus baris WLR_NO_HARDWARE_CURSORS
                sed -i '/^export WLR_NO_HARDWARE_CURSORS/d' "$profile_file"
                # Hapus baris kosong berlebihan
                sed -i '/^$/N;/^\n$/d' "$profile_file"

                log_ok "Autostart sway dihapus dari $profile_file"
            else
                log_skip "Tidak ada autostart sway di $profile_file"
            fi
        else
            log_skip "$profile_file tidak ditemukan."
        fi
    done
else
    log_skip "Melewati penghapusan autostart."
fi

# ============================================================================
# STEP 5: Bersihkan orphan packages
# ============================================================================
step_title "5 - BERSIHKAN ORPHAN PACKAGES"

echo ""
log_info "Menghapus paket orphan (dependensi yang tidak lagi dibutuhkan)..."
echo ""

if ask_yes_no "===> Jalankan xbps-remove -o (hapus orphan)?"; then
    sudo xbps-remove -o -y 2>/dev/null && log_ok "Orphan packages dibersihkan." || log_warn "Tidak ada orphan atau gagal membersihkan."
else
    log_skip "Melewati pembersihan orphan."
fi

# ============================================================================
# DONE
# ============================================================================
echo ""
echo -e "${C_BOLD}${C_DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
echo -e "${C_GREEN}${C_BOLD}  Uninstall void-sway selesai!${C_RESET}"
echo -e "${C_BOLD}${C_DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
echo ""
if [ -d "${BACKUP_DIR:-}" ]; then
    echo -e "  Backup folder: ${C_CYAN}$BACKUP_DIR${C_RESET}"
fi
echo ""
echo "  Langkah selanjutnya:"
echo "    1. Install ZSpace jika belum:  cd ~/zspace && ./install.sh"
echo "    2. Reboot sistem:              sudo reboot"
echo ""
