#!/usr/bin/env bash
# =============================================================================
#  ArcOS Installer
#  github.com/arclen-dev/arcos
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

TOTAL_STEPS=11
CURRENT_STEP=0
INSTALL_START=$(date +%s)

info()    { echo -e "  ${CYAN}${BOLD}➜${RESET}  $*"; }
success() { echo -e "  ${GREEN}${BOLD}✔${RESET}  $*"; }
warn()    { echo -e "  ${YELLOW}${BOLD}!${RESET}  ${YELLOW}$*${RESET}"; }
error()   { echo -e "\n  ${RED}${BOLD}✘  ERROR:${RESET} $*\n"; exit 1; }

step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local title="$*"
    local progress="Step ${CURRENT_STEP}/${TOTAL_STEPS}"
    local width=54
    local content="  ${progress} — ${title}  "
    local pad=$(( (width - ${#content}) / 2 ))
    local padstr=""
    for ((i=0; i<pad; i++)); do padstr="${padstr} "; done
    echo ""
    echo -e "  ${CYAN}┌──────────────────────────────────────────────────────┐${RESET}"
    echo -e "  ${CYAN}│${RESET}${padstr}${BOLD}${WHITE}${progress} — ${title}${RESET}${padstr}${CYAN}│${RESET}"
    echo -e "  ${CYAN}└──────────────────────────────────────────────────────┘${RESET}"
}

spinner() {
    local pid=$1
    local msg="${2:-Working...}"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r  ${CYAN}${frames[$((i % 10))]}${RESET}  ${DIM}%s${RESET}" "$msg"
        sleep 0.1
        i=$((i + 1))
    done
    printf "\r%-60s\r" " "
}

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sudo_keepalive() {
    while true; do sudo -v; sleep 240; done &
    SUDO_KEEPALIVE_PID=$!
}
stop_keepalive() {
    [[ -n "${SUDO_KEEPALIVE_PID:-}" ]] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
}
trap stop_keepalive EXIT

# ── Banner ────────────────────────────────────────────────────────────────────
clear
echo -e "${CYAN}${BOLD}"
cat << 'EOF'

    ___             ____  _____
   /   |  __________/ __ \/ ___/
  / /| | / ___/ ___/ / / /\__ \
 / ___ |/ /  / /__/ /_/ /___/ /
/_/  |_/_/   \___/\____//____/

EOF
echo -e "${RESET}"
echo -e "  ${WHITE}${BOLD}Hyprland rice installer${RESET}  ${DIM}by arclen-dev${RESET}"
echo -e "  ${DIM}github.com/arclen-dev/arcos${RESET}"
echo -e "  ${DIM}────────────────────────────────────────${RESET}\n"

# ── Pre-flight checks ─────────────────────────────────────────────────────────
echo -e "  ${CYAN}${BOLD}Running pre-flight checks...${RESET}\n"

[[ "$EUID" -eq 0 ]] && error "Do not run as root. Run as your normal user."
success "Running as user: ${BOLD}$USER${RESET}"

[[ -f /etc/arch-release ]] || error "This installer requires an Arch-based distro."
success "Arch-based distro detected"

if ! sudo -v &>/dev/null; then
    error "User $USER does not have sudo access."
fi
success "sudo access confirmed"

if ! command -v git &>/dev/null; then
    info "git not found — installing..."
    sudo pacman -S --noconfirm git || error "Failed to install git."
fi
success "git available"

info "Checking internet connection..."
INET_OK=false
for host in archlinux.org 8.8.8.8 1.1.1.1; do
    if ping -c 1 -W 2 "$host" &>/dev/null; then INET_OK=true; break; fi
done
[[ "$INET_OK" == true ]] || error "No internet connection detected."
success "Internet OK"

FREE_GB=$(df -BG / | awk 'NR==2 {gsub("G",""); print $4}')
if [[ "$FREE_GB" -lt 10 ]]; then
    warn "Only ${FREE_GB}GB free on /. Recommended: 10GB+."
else
    success "Disk space OK (${FREE_GB}GB free)"
fi

info "Detecting GPU..."
GPU_DETECTED=""
GPU_NAME=""
if lspci 2>/dev/null | grep -qi "nvidia"; then
    GPU_DETECTED="nvidia"
    GPU_NAME=$(lspci | grep -i nvidia | head -1 | sed 's/.*: //')
elif lspci 2>/dev/null | grep -qi "amd\|radeon"; then
    GPU_DETECTED="amd"
    GPU_NAME=$(lspci | grep -iE "amd|radeon" | head -1 | sed 's/.*: //')
elif lspci 2>/dev/null | grep -qi "intel.*graphics\|intel.*vga"; then
    GPU_DETECTED="intel"
    GPU_NAME=$(lspci | grep -iE "intel.*graphics|intel.*vga" | head -1 | sed 's/.*: //')
fi
[[ -n "$GPU_DETECTED" ]] && success "GPU detected: ${BOLD}$GPU_NAME${RESET}" || warn "Could not auto-detect GPU."
echo ""

sudo_keepalive

# ── Step 1: Configuration questions ──────────────────────────────────────────
echo -e "  ${CYAN}${BOLD}Configuration${RESET}\n"
echo -e "  ${DIM}Answer the following. The install will then run unattended.${RESET}\n"

# GPU
echo -e "  ${BOLD}[1] GPU type${RESET}"
if [[ -n "$GPU_DETECTED" ]]; then
    echo -e "      ${DIM}Auto-detected:${RESET} ${GREEN}${GPU_NAME}${RESET}"
    echo -e "      1) Use detected ${DIM}(${GPU_DETECTED})${RESET}  2) Intel  3) AMD  4) NVIDIA"
    read -rp "      Choice [1/2/3/4, default=1]: " GPU_CHOICE
    GPU_CHOICE="${GPU_CHOICE:-1}"
    case "$GPU_CHOICE" in
        1) GPU="$GPU_DETECTED" ;; 2) GPU="intel" ;; 3) GPU="amd" ;; 4) GPU="nvidia" ;;
        *) warn "Invalid, using auto-detected"; GPU="$GPU_DETECTED" ;;
    esac
else
    echo -e "      1) Intel  2) AMD  3) NVIDIA"
    while true; do
        read -rp "      Choice [1/2/3]: " GPU_CHOICE
        case "$GPU_CHOICE" in
            1) GPU="intel"; break ;; 2) GPU="amd"; break ;; 3) GPU="nvidia"; break ;;
            *) warn "Invalid choice." ;;
        esac
    done
fi

echo ""
echo -e "  ${BOLD}[2] Is this a laptop?${RESET} ${DIM}(installs power management, touchpad, backlight tools)${RESET}"
read -rp "      [y/N]: " IS_LAPTOP
IS_LAPTOP="${IS_LAPTOP,,}"

echo ""
echo -e "  ${BOLD}[3] Install Bluetooth?${RESET} ${DIM}(bluez, bluez-utils, blueman)${RESET}"
read -rp "      [y/N]: " INSTALL_BT
INSTALL_BT="${INSTALL_BT,,}"

echo ""
echo -e "  ${BOLD}[4] Detected username:${RESET} ${GREEN}${BOLD}$USER${RESET}"
read -rp "      Is this correct? [Y/n]: " CONFIRM_USER
[[ "${CONFIRM_USER,,}" == "n" ]] && error "Run the installer as the correct user."

echo ""
echo -e "  ${CYAN}┌─────────────────────────────────────────────────────────┐${RESET}"
echo -e "  ${CYAN}│${RESET}  ${BOLD}${WHITE}Install Summary${RESET}"
echo -e "  ${CYAN}│${RESET}  ${DIM}User      ${RESET} ${BOLD}$USER${RESET}"
echo -e "  ${CYAN}│${RESET}  ${DIM}GPU       ${RESET} ${BOLD}$GPU${RESET}"
echo -e "  ${CYAN}│${RESET}  ${DIM}Laptop    ${RESET} ${BOLD}${IS_LAPTOP:-n}${RESET}"
echo -e "  ${CYAN}│${RESET}  ${DIM}Bluetooth ${RESET} ${BOLD}${INSTALL_BT:-n}${RESET}"
echo -e "  ${CYAN}└─────────────────────────────────────────────────────────┘${RESET}"
echo ""
read -rp "  Looks good? Press Enter to begin or Ctrl+C to cancel... "

# ── Step 2: Chaotic AUR ───────────────────────────────────────────────────────
step "Setting up Chaotic AUR"

# CachyOS ships with chaotic-aur already configured — skip if already present
if grep -q "chaotic-aur" /etc/pacman.conf; then
    success "Chaotic AUR already configured — skipping keyring step"
else
    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    sudo pacman-key --lsign-key 3056513887B78AEB
    sudo pacman -U --noconfirm \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
    sudo pacman -U --noconfirm \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
    echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" \
        | sudo tee -a /etc/pacman.conf > /dev/null
    success "Chaotic AUR configured"
fi

sudo pacman -Sy
info "Installing yay..."
sudo pacman -S --needed --noconfirm yay
success "yay ready"

# ── Step 3: Install packages ──────────────────────────────────────────────────
step "Installing packages"

# Resolve jack conflict before installing: remove jack2 if present
if pacman -Q jack2 &>/dev/null; then
    info "Removing jack2 to avoid conflict with pipewire-jack..."
    sudo pacman -Rdd --noconfirm jack2 2>/dev/null || true
    success "jack2 removed"
fi

PKGS=$(grep -v '^#' "$REPO_DIR/packages.txt" | grep -v '^$' | tr '\n' ' ')

case "$GPU" in
    # intel-media-driver covers Broadwell (2014) and newer.
    # libva-intel-driver covers older chips up to Haswell (2013).
    # Both can coexist — mesa provides the Vulkan driver for Intel.
    intel)  GPU_PKGS="mesa vulkan-intel intel-media-driver libva-intel-driver" ;;
    amd)    GPU_PKGS="mesa vulkan-radeon libva-mesa-driver" ;;
    nvidia) GPU_PKGS="nvidia nvidia-utils nvidia-settings libva-nvidia-driver" ;;
esac
info "GPU packages for ${BOLD}$GPU${RESET}: $GPU_PKGS"
PKGS="$PKGS $GPU_PKGS"

[[ "$INSTALL_BT" == "y" ]] && PKGS="$PKGS bluez bluez-utils blueman"
[[ "$IS_LAPTOP"  == "y" ]] && PKGS="$PKGS power-profiles-daemon acpi acpid brightnessctl xf86-input-libinput iio-sensor-proxy"

info "Installing all packages — this will take a while, grab a coffee ☕"
yay -S --needed --noconfirm $PKGS
success "All packages installed"

# ── Step 4: SDDM theme ───────────────────────────────────────────────────────
step "Installing SDDM silent theme"
yay -S --needed --noconfirm sddm-silent-theme
success "sddm-silent-theme installed"

# ── Step 5: Fonts ────────────────────────────────────────────────────────────
step "Installing fonts"
mkdir -p "$HOME/.local/share/fonts"
if [[ -d "$REPO_DIR/fonts" ]]; then
    cp -r "$REPO_DIR/fonts/"* "$HOME/.local/share/fonts/"
    success "Fonts copied from repo"
else
    info "Downloading Inter font..."
    mkdir -p /tmp/inter-install
    curl -L https://github.com/rsms/inter/releases/latest/download/Inter.zip \
        -o /tmp/inter-install/Inter.zip
    unzip -o /tmp/inter-install/Inter.zip -d /tmp/inter-install/
    find /tmp/inter-install -name "*.ttf" -exec cp {} "$HOME/.local/share/fonts/" \;
    rm -rf /tmp/inter-install
    success "Inter font downloaded"
fi
fc-cache -fv &>/dev/null
success "Font cache updated"

# ── Step 6: Backup existing configs ──────────────────────────────────────────
step "Backing up existing configs"
BACKUP_DIR="$HOME/.config.bak-arcos-$(date +%Y%m%d-%H%M%S)"
DOTFILES_TO_COPY=(hypr waybar rofi kitty swaync hypridle wallust swayosd btop fresh gtk-3.0 gtk-4.0 nwg-look geany qt6ct fish)
mkdir -p "$BACKUP_DIR"
for folder in "${DOTFILES_TO_COPY[@]}"; do
    [[ -d "$HOME/.config/$folder" ]] && cp -r "$HOME/.config/$folder" "$BACKUP_DIR/" && success "Backed up $folder"
done

# ── Step 7: Copy dotfiles ─────────────────────────────────────────────────────
step "Installing dotfiles"
DOTFILES="$REPO_DIR/dotfiles"

copy_config() {
    local src="$DOTFILES/$1"
    local dst="$HOME/.config/$1"
    if [[ -e "$src" ]]; then
        mkdir -p "$dst"
        cp -r "$src/." "$dst/"
        success "Copied $1"
    else
        warn "Skipping $1 (not found in repo)"
    fi
}

copy_config "hypr"
copy_config "waybar"
copy_config "rofi"
copy_config "kitty"
copy_config "swaync"
copy_config "hypridle"
copy_config "wallust"
copy_config "swayosd"
copy_config "btop"
copy_config "fresh"
copy_config "gtk-3.0"
copy_config "gtk-4.0"
copy_config "nwg-look"
copy_config "geany"
copy_config "qt6ct"

# Fish config
if [[ -d "$REPO_DIR/fish" ]]; then
    mkdir -p "$HOME/.config/fish"
    cp -r "$REPO_DIR/fish/." "$HOME/.config/fish/"
    success "Copied fish config"
fi

chmod +x "$HOME/.config/hypr/scripts/"*.sh 2>/dev/null || true
success "Scripts made executable"

# Generate resolution-aware hyprlock config
info "Generating hyprlock layout config..."
bash "$HOME/.config/hypr/scripts/hyprlock-gen.sh" --now 2>/dev/null || \
    warn "hyprlock-gen skipped (Hyprland not running yet — auto-runs on next login)"

mkdir -p "$HOME/Pictures/Screenshots" "$HOME/Pictures/Wallpapers"

# ── Step 8: System configs ────────────────────────────────────────────────────
step "Applying system configs"

[[ -f "$REPO_DIR/system/99-swappiness.conf" ]] && \
    sudo cp "$REPO_DIR/system/99-swappiness.conf" /etc/sysctl.d/ && \
    sudo sysctl vm.swappiness=20 && success "Swappiness set to 20"

[[ -f "$REPO_DIR/system/sddm.conf" ]] && \
    sudo cp "$REPO_DIR/system/sddm.conf" /etc/sddm.conf && success "SDDM config applied"

sudo usermod -aG input "$USER"
success "Added $USER to input group"

if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    gsettings set org.gnome.desktop.interface gtk-theme      "adw-gtk3-dark"         2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme     "Papirus-Dark"           2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-theme   "Bibata-Modern-Classic"  2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-size    24                       2>/dev/null || true
    gsettings set org.gnome.desktop.interface color-scheme   "prefer-dark"            2>/dev/null || true
    success "GTK theme, icons and cursor applied"
else
    info "gsettings skipped (no DBus session — will apply on first login via nwg-look)"
fi

# ── Step 9: XDG user dirs ─────────────────────────────────────────────────────
step "Setting up XDG user directories"
xdg-user-dirs-update --force
success "XDG user dirs created"

# ── Step 10: Enable services ──────────────────────────────────────────────────
step "Enabling services"

sudo systemctl enable sddm
success "sddm enabled"

sudo systemctl enable NetworkManager
success "NetworkManager enabled"

systemctl --user enable --now playerctld 2>/dev/null || true
success "playerctld enabled"

if [[ "$INSTALL_BT" == "y" ]]; then
    sudo systemctl enable bluetooth
    success "bluetooth enabled"
fi

if [[ "$IS_LAPTOP" == "y" ]]; then
    sudo systemctl enable --now power-profiles-daemon 2>/dev/null || \
        warn "power-profiles-daemon not found (may already be active on CachyOS)"
    sudo systemctl enable acpid
    success "Laptop power management enabled"
fi

# Set Fish as default shell
if command -v fish &>/dev/null; then
    FISH_PATH="$(which fish)"
    chsh -s "$FISH_PATH" "$USER"
    success "Default shell set to Fish"
else
    warn "fish not found in PATH — shell not changed"
fi

# ── Step 11: Final setup ──────────────────────────────────────────────────────
step "Final setup"

FIRST_WALLPAPER=$(find "$HOME/Pictures/Wallpapers" -type f \
    \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" -o -iname "*.webp" \) | head -1)
if [[ -n "$FIRST_WALLPAPER" ]]; then
    mkdir -p "$HOME/.cache/wallust"
    wallust run "$FIRST_WALLPAPER" 2>/dev/null || true
    echo "$FIRST_WALLPAPER" > "$HOME/.cache/wallust/wallpaper"
    success "wallust initialized with: $(basename "$FIRST_WALLPAPER")"
else
    warn "No wallpapers found — add some to ~/Pictures/Wallpapers and run: wallust run ~/Pictures/Wallpapers/yourwallpaper.jpg"
fi

paccache -rk2 2>/dev/null || true
success "Package cache cleaned"

# ── Done ──────────────────────────────────────────────────────────────────────
INSTALL_END=$(date +%s)
INSTALL_DURATION=$(( (INSTALL_END - INSTALL_START) / 60 ))

clear
echo -e "${CYAN}${BOLD}"
cat << 'EOF'

    ___             ____  _____
   /   |  __________/ __ \/ ___/
  / /| | / ___/ ___/ / / /\__ \
 / ___ |/ /  / /__/ /_/ /___/ /
/_/  |_/_/   \___/\____//____/

EOF
echo -e "${RESET}"
echo -e "  ${GREEN}${BOLD}✔  Installation complete!${RESET}  ${DIM}(took ~${INSTALL_DURATION} min)${RESET}"
echo ""
echo -e "  ${CYAN}┌─────────────────────────────────────────────────────────┐${RESET}"
echo -e "  ${CYAN}│${RESET}  ${BOLD}${WHITE}Keybinds${RESET}"
echo -e "  ${CYAN}│${RESET}  ${DIM}─────────────────────────────────────────────────────${RESET}"
echo -e "  ${CYAN}│${RESET}  ${CYAN}Super + Enter${RESET}        Terminal (kitty)"
echo -e "  ${CYAN}│${RESET}  ${CYAN}Super + Space${RESET}        App launcher (rofi)"
echo -e "  ${CYAN}│${RESET}  ${CYAN}Super + E${RESET}            File manager (Thunar)"
echo -e "  ${CYAN}│${RESET}  ${CYAN}Super + W${RESET}            Wallpaper picker"
echo -e "  ${CYAN}│${RESET}  ${CYAN}Super + Shift+W${RESET}      Toggle dark/light mode"
echo -e "  ${CYAN}│${RESET}  ${CYAN}Super + L${RESET}            Lock screen"
echo -e "  ${CYAN}│${RESET}  ${CYAN}Super + X${RESET}            Power menu"
echo -e "  ${CYAN}│${RESET}  ${CYAN}Super + P${RESET}            Audio mixer (pwvucontrol)"
echo -e "  ${CYAN}│${RESET}  ${CYAN}Super + N${RESET}            Notification center"
echo -e "  ${CYAN}│${RESET}  ${CYAN}Super + V / .${RESET}        Clipboard / Emoji picker"
echo -e "  ${CYAN}│${RESET}  ${CYAN}Super + F${RESET}            Fullscreen"
echo -e "  ${CYAN}│${RESET}  ${CYAN}Super + Shift+F${RESET}      Toggle floating"
echo -e "  ${CYAN}│${RESET}  ${CYAN}Shift + Alt + Arrows${RESET} Move window in workspace"
echo -e "  ${CYAN}│${RESET}  ${CYAN}Super + Q${RESET}            Close window"
echo -e "  ${CYAN}│${RESET}  ${CYAN}Print${RESET}                Screenshot (region)"
echo -e "  ${CYAN}└─────────────────────────────────────────────────────────┘${RESET}"
echo ""
echo -e "  ${CYAN}┌─────────────────────────────────────────────────────────┐${RESET}"
echo -e "  ${CYAN}│${RESET}  ${BOLD}${WHITE}Post-install steps${RESET}"
echo -e "  ${CYAN}│${RESET}  ${DIM}─────────────────────────────────────────────────────${RESET}"
echo -e "  ${CYAN}│${RESET}  ${YELLOW}1.${RESET} Set your resolution in ${BOLD}~/.config/hypr/monitor.conf${RESET}"
echo -e "  ${CYAN}│${RESET}     Run ${BOLD}hyprctl monitors${RESET} to find your monitor name"
echo -e "  ${CYAN}│${RESET}  ${YELLOW}2.${RESET} Add wallpapers to ${BOLD}~/Pictures/Wallpapers${RESET}"
echo -e "  ${CYAN}│${RESET}     Press ${BOLD}Super + W${RESET} to pick one after reboot"
echo -e "  ${CYAN}│${RESET}  ${YELLOW}3.${RESET} On first reboot, do a second reboot if anything looks off"
echo -e "  ${CYAN}└─────────────────────────────────────────────────────────┘${RESET}"
echo ""
echo -e "  ${YELLOW}${BOLD}  ⚠  Reboot now to complete the setup${RESET}"
echo -e "     ${BOLD}sudo reboot${RESET}"
echo ""
