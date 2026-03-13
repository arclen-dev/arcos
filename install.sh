#!/usr/bin/env bash
# =============================================================================
#  ArcOS Installer
#  github.com/arclen-dev/arcos
# =============================================================================

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Step tracking ─────────────────────────────────────────────────────────────
TOTAL_STEPS=14
CURRENT_STEP=0
INSTALL_START=$(date +%s)

# ── Helpers ───────────────────────────────────────────────────────────────────
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

box() {
    local msg="$*"
    echo -e "  ${DIM}┌──────────────────────────────────────────────────────┐${RESET}"
    echo -e "  ${DIM}│${RESET}  $msg"
    echo -e "  ${DIM}└──────────────────────────────────────────────────────┘${RESET}"
}

# Spinner for long-running commands
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

# ── Sudo keepalive ────────────────────────────────────────────────────────────
sudo_keepalive() {
    while true; do
        sudo -v
        sleep 240
    done &
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

# ── Step 0: Pre-flight checks ─────────────────────────────────────────────────
echo -e "  ${CYAN}${BOLD}Running pre-flight checks...${RESET}\n"

# Not root
[[ "$EUID" -eq 0 ]] && error "Do not run as root. Run as your normal user."
success "Running as user: ${BOLD}$USER${RESET}"

# Arch Linux
[[ -f /etc/arch-release ]] || error "This installer is for Arch Linux only."
success "Arch Linux detected"

# sudo access
if ! sudo -v &>/dev/null; then
    error "User $USER does not have sudo access. Add yourself to the sudoers file first."
fi
success "sudo access confirmed"

# git installed
if ! command -v git &>/dev/null; then
    info "git not found — installing..."
    sudo pacman -S --noconfirm git || error "Failed to install git."
fi
success "git available"

# Internet check
info "Checking internet connection..."
INET_OK=false
for host in archlinux.org 8.8.8.8 1.1.1.1; do
    if ping -c 1 -W 2 "$host" &>/dev/null; then
        INET_OK=true
        break
    fi
done
[[ "$INET_OK" == true ]] || error "No internet connection detected. Check your network and try again."
success "Internet OK"

# Disk space — warn if less than 10GB free
FREE_GB=$(df -BG / | awk 'NR==2 {gsub("G",""); print $4}')
if [[ "$FREE_GB" -lt 10 ]]; then
    warn "Only ${FREE_GB}GB free on /. Recommended: 10GB+. Proceeding anyway..."
else
    success "Disk space OK (${FREE_GB}GB free)"
fi

# GPU detection
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

if [[ -n "$GPU_DETECTED" ]]; then
    success "GPU detected: ${BOLD}$GPU_NAME${RESET}"
else
    warn "Could not auto-detect GPU. You will be asked manually."
fi

echo ""

# Start sudo keepalive now that sudo is confirmed
sudo_keepalive

# ── Step 1: Ask all questions upfront ─────────────────────────────────────────
echo -e "  ${CYAN}${BOLD}Configuration${RESET}\n"
echo -e "  ${DIM}Answer the following. The install will then run unattended.${RESET}\n"

# GPU
echo -e "  ${BOLD}[1] GPU type${RESET}"
if [[ -n "$GPU_DETECTED" ]]; then
    echo -e "      ${DIM}Auto-detected:${RESET} ${GREEN}${GPU_NAME}${RESET}"
    echo -e "      1) Use detected ${DIM}(${GPU_DETECTED})${RESET}"
    echo -e "      2) Intel"
    echo -e "      3) AMD"
    echo -e "      4) NVIDIA"
    read -rp "      Choice [1/2/3/4, default=1]: " GPU_CHOICE
    GPU_CHOICE="${GPU_CHOICE:-1}"
    case "$GPU_CHOICE" in
        1) GPU="$GPU_DETECTED" ;;
        2) GPU="intel"  ;;
        3) GPU="amd"    ;;
        4) GPU="nvidia" ;;
        *) warn "Invalid choice, using auto-detected: $GPU_DETECTED"; GPU="$GPU_DETECTED" ;;
    esac
else
    echo -e "      1) Intel"
    echo -e "      2) AMD"
    echo -e "      3) NVIDIA"
    while true; do
        read -rp "      Choice [1/2/3]: " GPU_CHOICE
        case "$GPU_CHOICE" in
            1) GPU="intel";  break ;;
            2) GPU="amd";    break ;;
            3) GPU="nvidia"; break ;;
            *) warn "Invalid choice. Please enter 1, 2 or 3." ;;
        esac
    done
fi

# Laptop
echo ""
echo -e "  ${BOLD}[2] Is this a laptop?${RESET} ${DIM}(installs power management, touchpad, backlight tools)${RESET}"
read -rp "      [y/N]: " IS_LAPTOP
IS_LAPTOP="${IS_LAPTOP,,}"

# Bluetooth
echo ""
echo -e "  ${BOLD}[3] Install and enable Bluetooth?${RESET} ${DIM}(bluez, bluez-utils, blueman)${RESET}"
read -rp "      [y/N]: " INSTALL_BT
INSTALL_BT="${INSTALL_BT,,}"

# Username confirm
echo ""
echo -e "  ${BOLD}[4] Detected username:${RESET} ${GREEN}${BOLD}$USER${RESET}"
read -rp "      Is this correct? [Y/n]: " CONFIRM_USER
CONFIRM_USER="${CONFIRM_USER,,}"
[[ "$CONFIRM_USER" == "n" ]] && error "Please run the installer as the correct user."

# Summary box
echo ""
echo -e "  ${CYAN}┌─────────────────────────────────────────────────────────┐${RESET}"
echo -e "  ${CYAN}│${RESET}  ${BOLD}${WHITE}Install Summary${RESET}"
echo -e "  ${CYAN}│${RESET}  ${DIM}─────────────────────────────────────────────────────${RESET}"
echo -e "  ${CYAN}│${RESET}  ${DIM}User     ${RESET} ${BOLD}$USER${RESET}"
echo -e "  ${CYAN}│${RESET}  ${DIM}GPU      ${RESET} ${BOLD}$GPU${RESET}"
echo -e "  ${CYAN}│${RESET}  ${DIM}Laptop   ${RESET} ${BOLD}${IS_LAPTOP:-n}${RESET}"
echo -e "  ${CYAN}│${RESET}  ${DIM}Bluetooth${RESET} ${BOLD}${INSTALL_BT:-n}${RESET}"
echo -e "  ${CYAN}└─────────────────────────────────────────────────────────┘${RESET}"
echo ""
read -rp "  Looks good? Press Enter to begin or Ctrl+C to cancel... "

# ── Step 2: Chaotic AUR ───────────────────────────────────────────────────────
step "Setting up Chaotic AUR"

sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
sudo pacman-key --lsign-key 3056513887B78AEB
sudo pacman -U --noconfirm \
    'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
sudo pacman -U --noconfirm \
    'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
grep -q "chaotic-aur" /etc/pacman.conf || \
    echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" \
    | sudo tee -a /etc/pacman.conf > /dev/null
info "Sorting Chaotic AUR mirrors by speed..."
sudo pacman -S --noconfirm rate-mirrors 2>/dev/null || true
rate-mirrors --allow-root chaotic-aur 2>/dev/null | sudo tee /etc/pacman.d/chaotic-mirrorlist > /dev/null || \
    warn "Mirror sorting failed — using default mirrorlist"
sudo pacman -Sy
success "Chaotic AUR configured"

# Install yay
info "Installing yay..."
sudo pacman -S --needed --noconfirm yay
success "yay ready"

# ── Step 3: Install packages ──────────────────────────────────────────────────
step "Installing packages"

PKGS=$(grep -v '^#' "$REPO_DIR/packages.txt" | grep -v '^$' | tr '\n' ' ')

case "$GPU" in
    intel)  GPU_PKGS="mesa intel-media-driver vulkan-intel libva-intel-driver" ;;
    amd)    GPU_PKGS="mesa vulkan-radeon libva-mesa-driver amdvlk" ;;
    nvidia) GPU_PKGS="nvidia nvidia-utils nvidia-settings libva-nvidia-driver" ;;
esac
info "GPU driver packages for ${BOLD}$GPU${RESET}: $GPU_PKGS"
PKGS="$PKGS $GPU_PKGS"

[[ "$INSTALL_BT" == "y" ]] && PKGS="$PKGS bluez bluez-utils blueman"
[[ "$IS_LAPTOP" == "y" ]]  && PKGS="$PKGS tlp tlp-rdw acpi acpid brightnessctl xf86-input-libinput"

info "Installing all packages — this will take a while, grab a coffee ☕"
yay -S --needed --noconfirm $PKGS
success "All packages installed"

# ── Step 4: sddm-silent-theme ─────────────────────────────────────────────────
step "Installing SDDM silent theme"

yay -S --needed --noconfirm sddm-silent-theme
success "sddm-silent-theme installed"

# ── Step 5: Fonts ─────────────────────────────────────────────────────────────
step "Installing fonts"

mkdir -p "$HOME/.local/share/fonts"
if [[ -d "$REPO_DIR/fonts" ]]; then
    info "Copying bundled fonts..."
    cp -r "$REPO_DIR/fonts/"* "$HOME/.local/share/fonts/"
    success "Fonts copied from repo"
else
    info "Downloading Inter font from rsms/inter (official source)..."
    mkdir -p /tmp/inter-install
    curl -L https://github.com/rsms/inter/releases/latest/download/Inter.zip \
        -o /tmp/inter-install/Inter.zip
    unzip -o /tmp/inter-install/Inter.zip -d /tmp/inter-install/
    find /tmp/inter-install -name "*.ttf" -exec cp {} "$HOME/.local/share/fonts/" \;
    rm -rf /tmp/inter-install
    success "Inter font downloaded and installed"
fi
fc-cache -fv &>/dev/null
success "Font cache updated"

# ── Step 6: Oh My Zsh ─────────────────────────────────────────────────────────
step "Installing Oh My Zsh"

info "Installing Oh My Zsh (unattended)..."
rm -rf "$HOME/.oh-my-zsh" 2>/dev/null || true
RUNZSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    "" --unattended
success "Oh My Zsh installed"

# ── Step 7: Powerlevel10k ─────────────────────────────────────────────────────
step "Installing Powerlevel10k"

P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
info "Cloning Powerlevel10k..."
rm -rf "$P10K_DIR" 2>/dev/null || true
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
success "Powerlevel10k installed"

# ── Step 8: ZSH plugins ───────────────────────────────────────────────────────
step "Installing ZSH plugins"

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

info "Installing zsh-autosuggestions..."
rm -rf "$ZSH_CUSTOM/plugins/zsh-autosuggestions" 2>/dev/null || true
git clone https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
success "zsh-autosuggestions installed"

info "Installing zsh-syntax-highlighting..."
rm -rf "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" 2>/dev/null || true
git clone https://github.com/zsh-users/zsh-syntax-highlighting \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
success "zsh-syntax-highlighting installed"

# ── Step 9: Backup existing configs ───────────────────────────────────────────
step "Backing up existing configs"

BACKUP_DIR="$HOME/.config.bak-arcos-$(date +%Y%m%d-%H%M%S)"
DOTFILES_TO_COPY=(hypr waybar rofi kitty swaync wallust swayosd btop fresh gtk-3.0 gtk-4.0 nwg-look geany qt6ct)
info "Backing up ArcOS-related config folders to $BACKUP_DIR ..."
mkdir -p "$BACKUP_DIR"
for folder in "${DOTFILES_TO_COPY[@]}"; do
    [[ -d "$HOME/.config/$folder" ]] && cp -r "$HOME/.config/$folder" "$BACKUP_DIR/" && success "Backed up $folder"
done
[[ -f "$HOME/.zshrc" ]]    && cp "$HOME/.zshrc"    "$HOME/.zshrc.bak-arcos"    && success ".zshrc backed up"
[[ -f "$HOME/.p10k.zsh" ]] && cp "$HOME/.p10k.zsh" "$HOME/.p10k.zsh.bak-arcos" && success ".p10k.zsh backed up"

# ── Step 10: Copy dotfiles ────────────────────────────────────────────────────
step "Installing dotfiles"

DOTFILES="$REPO_DIR/dotfiles"

copy_config() {
    local src="$DOTFILES/$1"
    local dst="$HOME/.config/$1"
    if [[ -e "$src" ]]; then
        mkdir -p "$(dirname "$dst")"
        cp -r "$src" "$dst"
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
copy_config "wallust"
copy_config "swayosd"
copy_config "btop"
copy_config "fresh"
copy_config "gtk-3.0"
copy_config "gtk-4.0"
copy_config "nwg-look"
copy_config "geany"
copy_config "qt6ct"

[[ -f "$REPO_DIR/zsh/.zshrc" ]]    && cp "$REPO_DIR/zsh/.zshrc"    "$HOME/.zshrc"    && success "Copied .zshrc"
[[ -f "$REPO_DIR/zsh/.p10k.zsh" ]] && cp "$REPO_DIR/zsh/.p10k.zsh" "$HOME/.p10k.zsh" && success "Copied .p10k.zsh"

chmod +x "$HOME/.config/hypr/scripts/"*.sh 2>/dev/null || true
success "Scripts made executable"

mkdir -p "$HOME/Pictures/Wallpapers"
if [[ -d "$REPO_DIR/assets/wallpapers" ]]; then
    cp "$REPO_DIR/assets/wallpapers/"* "$HOME/Pictures/Wallpapers/" 2>/dev/null || true
    success "Wallpapers copied"
fi

# ── Step 11: System configs ───────────────────────────────────────────────────
step "Applying system configs"

[[ -f "$REPO_DIR/system/99-swappiness.conf" ]] && \
    sudo cp "$REPO_DIR/system/99-swappiness.conf" /etc/sysctl.d/ && \
    sudo sysctl vm.swappiness=20 && \
    success "Swappiness set to 20"

[[ -f "$REPO_DIR/system/sddm.conf" ]] && \
    sudo cp "$REPO_DIR/system/sddm.conf" /etc/sddm.conf && \
    success "SDDM config applied"

sudo usermod -aG input "$USER"
success "Added $USER to input group"

# Apply GTK theme, icons and cursor silently via gsettings
if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark"       2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"        2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-theme "Bibata-Modern-Classic" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-size 24                   2>/dev/null || true
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"       2>/dev/null || true
    success "GTK theme, icons and cursor applied"
else
    info "gsettings skipped (no DBus session — will apply on first login via nwg-look)"
fi

# ── Step 12: XDG user dirs ────────────────────────────────────────────────────
step "Setting up XDG user directories"

xdg-user-dirs-update --force
success "XDG user dirs created"

# ── Step 13: Enable services ──────────────────────────────────────────────────
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
    sudo systemctl enable tlp
    sudo systemctl enable acpid
    success "laptop power management enabled (tlp, acpid)"
fi

# ── Step 13b: Set ZSH as default shell ────────────────────────────────────────
ZSH_PATH="$(which zsh)"
chsh -s "$ZSH_PATH" "$USER"
success "Default shell set to ZSH"

# ── Step 14: Initial wallust run + cleanup ────────────────────────────────────
step "Final setup"

FIRST_WALLPAPER=$(find "$HOME/Pictures/Wallpapers" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) | head -1)
if [[ -n "$FIRST_WALLPAPER" ]]; then
    mkdir -p "$HOME/.cache/wallust"
    wallust run "$FIRST_WALLPAPER" 2>/dev/null || true
    echo "$FIRST_WALLPAPER" > "$HOME/.cache/wallust/wallpaper"
    success "wallust initialized with: $(basename "$FIRST_WALLPAPER")"
else
    warn "No wallpapers found — run manually after reboot: wallust run ~/Pictures/Wallpapers/yourwallpaper.jpg"
fi

paccache -rk2 2>/dev/null || true
rm -rf /tmp/arcos-* 2>/dev/null || true
success "Cache cleaned"

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
echo -e "  ${CYAN}│${RESET}  ${CYAN}Super + Enter${RESET}      Terminal (kitty)"
echo -e "  ${CYAN}│${RESET}  ${CYAN}Super + Space${RESET}      App launcher (rofi)"
echo -e "  ${CYAN}│${RESET}  ${CYAN}Super + E${RESET}          File manager (Thunar)"
echo -e "  ${CYAN}│${RESET}  ${CYAN}Super + W${RESET}          Wallpaper picker"
echo -e "  ${CYAN}│${RESET}  ${CYAN}Super + Shift+W${RESET}    Toggle dark/light mode"
echo -e "  ${CYAN}│${RESET}  ${CYAN}Super + L${RESET}          Lock screen"
echo -e "  ${CYAN}│${RESET}  ${CYAN}Super + X${RESET}          Power menu"
echo -e "  ${CYAN}│${RESET}  ${CYAN}Super + N${RESET}          Notification center"
echo -e "  ${CYAN}│${RESET}  ${CYAN}Super + V${RESET}          Clipboard history"
echo -e "  ${CYAN}│${RESET}  ${CYAN}Super + .${RESET}          Emoji picker"
echo -e "  ${CYAN}│${RESET}  ${CYAN}Super + Q${RESET}          Close window"
echo -e "  ${CYAN}│${RESET}  ${CYAN}Print${RESET}              Screenshot (region)"
echo -e "  ${CYAN}└─────────────────────────────────────────────────────────┘${RESET}"
echo ""
echo -e "  ${CYAN}┌─────────────────────────────────────────────────────────┐${RESET}"
echo -e "  ${CYAN}│${RESET}  ${BOLD}${WHITE}Post-install steps${RESET}"
echo -e "  ${CYAN}│${RESET}  ${DIM}─────────────────────────────────────────────────────${RESET}"
echo -e "  ${CYAN}│${RESET}  ${YELLOW}1.${RESET} Set your resolution, refresh rate and scaling:"
echo -e "  ${CYAN}│${RESET}     Edit ${BOLD}~/.config/hypr/monitor.conf${RESET}"
echo -e "  ${CYAN}│${RESET}     Run ${BOLD}hyprctl monitors${RESET} to find your monitor name"
echo -e "  ${CYAN}│${RESET}     Example: ${DIM}monitor=DP-1,1920x1080@60,0x0,1${RESET}"
echo -e "  ${CYAN}│${RESET}  ${YELLOW}2.${RESET} Set your wallpaper after reboot:"
echo -e "  ${CYAN}│${RESET}     Press ${BOLD}Super + W${RESET} to open the wallpaper picker"
echo -e "  ${CYAN}│${RESET}  ${YELLOW}3.${RESET} On first reboot things may not look perfect —"
echo -e "  ${CYAN}│${RESET}     ${DIM}do a second reboot if anything looks off${RESET}"
echo -e "  ${CYAN}└─────────────────────────────────────────────────────────┘${RESET}"
echo ""
echo -e "  ${YELLOW}${BOLD}  ⚠  Reboot now to complete the setup${RESET}"
echo -e "     ${BOLD}sudo reboot${RESET}"
echo ""
