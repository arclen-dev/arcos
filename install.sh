#!/usr/bin/env bash
# =============================================================================
#  ArcOS Installer
#  github.com/arclen-dev/arcos
# =============================================================================

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { echo -e "${CYAN}${BOLD}[ArcOS]${RESET} $*"; }
success() { echo -e "${GREEN}${BOLD}[ ✔ ]${RESET} $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[ ! ]${RESET} $*"; }
error()   { echo -e "${RED}${BOLD}[ ✘ ]${RESET} $*"; exit 1; }
step()    { echo -e "\n${BOLD}━━━ $* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
echo -e "${RESET}${BOLD}  Hyprland rice installer by arclen-dev${RESET}"
echo -e "  github.com/arclen-dev/arcos\n"

# ── Step 0: Pre-flight checks ─────────────────────────────────────────────────
step "Pre-flight checks"

[[ "$EUID" -eq 0 ]] && error "Do not run as root. Run as your normal user."
[[ -f /etc/arch-release ]] || error "This installer is for Arch Linux only."

info "Checking internet connection..."
ping -c 1 archlinux.org &>/dev/null || error "No internet connection detected."
success "Internet OK"

# ── Step 1: Ask all questions upfront ────────────────────────────────────────
step "Configuration"

echo -e "\n${BOLD}Please answer the following questions. The install will then run unattended.\n${RESET}"

# GPU
echo -e "  ${BOLD}[1] GPU type:${RESET}"
echo "      1) Intel"
echo "      2) AMD"
echo "      3) NVIDIA"
read -rp "  Choice [1/2/3]: " GPU_CHOICE
case "$GPU_CHOICE" in
    1) GPU="intel"  ;;
    2) GPU="amd"    ;;
    3) GPU="nvidia" ;;
    *) error "Invalid GPU choice." ;;
esac

# Laptop
echo ""
read -rp "  ${BOLD}[2] Is this a laptop? (enables bluetooth) [y/N]:${RESET} " IS_LAPTOP
IS_LAPTOP="${IS_LAPTOP,,}"

# Username confirm
echo ""
echo -e "  ${BOLD}[3] Detected username:${RESET} $USER"
read -rp "  Is this correct? [Y/n]: " CONFIRM_USER
CONFIRM_USER="${CONFIRM_USER,,}"
[[ "$CONFIRM_USER" == "n" ]] && error "Please run the installer as the correct user."

# Swap / hibernate
echo ""
info "Detecting swap partition for hibernate support..."
DETECTED_SWAP_UUID=""
SWAP_PART=$(lsblk -o NAME,FSTYPE | grep swap | awk '{print $1}' | head -1)
if [[ -n "$SWAP_PART" ]]; then
    DETECTED_SWAP_UUID=$(lsblk -o NAME,UUID,FSTYPE | grep swap | awk '{print $2}' | head -1)
    echo -e "  ${GREEN}Found swap:${RESET} /dev/$SWAP_PART (UUID: $DETECTED_SWAP_UUID)"
    read -rp "  Enable hibernate with this swap? [Y/n]: " ENABLE_HIBERNATE
    ENABLE_HIBERNATE="${ENABLE_HIBERNATE,,}"
else
    warn "No swap partition detected. Hibernate will be skipped."
    ENABLE_HIBERNATE="n"
fi

# Summary
echo -e "\n${BOLD}━━━ Install Summary ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  User:        $USER"
echo -e "  GPU:         $GPU"
echo -e "  Laptop:      $IS_LAPTOP"
echo -e "  Hibernate:   $ENABLE_HIBERNATE"
echo -e "  Swap UUID:   ${DETECTED_SWAP_UUID:-none}"
echo ""
read -rp "  Looks good? Press Enter to begin or Ctrl+C to cancel... "

# ── Step 2: Chaotic AUR ───────────────────────────────────────────────────────
step "Setting up Chaotic AUR"

if ! grep -q "chaotic-aur" /etc/pacman.conf 2>/dev/null; then
    info "Installing Chaotic AUR..."
    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    sudo pacman-key --lsign-key 3056513887B78AEB
    sudo pacman -U --noconfirm \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
    sudo pacman -U --noconfirm \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
    echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" \
        | sudo tee -a /etc/pacman.conf > /dev/null
    sudo pacman -Sy
    success "Chaotic AUR configured"
else
    success "Chaotic AUR already configured"
fi

# Install yay
if ! command -v yay &>/dev/null; then
    info "Installing yay..."
    sudo pacman -S --noconfirm yay
    success "yay installed"
else
    success "yay already installed"
fi

# ── Step 3: Install packages ──────────────────────────────────────────────────
step "Installing packages"

PKGS=$(grep -v '^#' "$REPO_DIR/packages.txt" | grep -v '^$' | tr '\n' ' ')

# GPU-specific packages
case "$GPU" in
    intel)
        PKGS="$PKGS intel-media-driver intel-ucode vulkan-intel libva-intel-driver"
        ;;
    amd)
        PKGS="$PKGS amd-ucode vulkan-radeon libva-mesa-driver"
        ;;
    nvidia)
        PKGS="$PKGS nvidia nvidia-utils nvidia-settings"
        ;;
esac

# Laptop: add bluetooth
[[ "$IS_LAPTOP" == "y" ]] && PKGS="$PKGS bluez bluez-utils blueman"

info "Installing all packages (this may take a while)..."
yay -S --needed --noconfirm $PKGS
success "All packages installed"

# ── Step 4: Inter font ────────────────────────────────────────────────────────
step "Installing Inter font"

if [[ -d "$REPO_DIR/fonts" ]]; then
    info "Copying bundled fonts..."
    mkdir -p "$HOME/.local/share/fonts"
    cp -r "$REPO_DIR/fonts/"* "$HOME/.local/share/fonts/"
    success "Fonts copied from repo"
else
    info "Downloading Inter font from rsms/inter (official source)..."
    mkdir -p /tmp/inter-install "$HOME/.local/share/fonts"
    curl -L https://github.com/rsms/inter/releases/latest/download/Inter.zip \
        -o /tmp/inter-install/Inter.zip
    unzip -o /tmp/inter-install/Inter.zip -d /tmp/inter-install/
    find /tmp/inter-install -name "*.ttf" -exec cp {} "$HOME/.local/share/fonts/" \;
    rm -rf /tmp/inter-install
    success "Inter font installed"
fi

# FiraCode Nerd Font (if bundled)
if [[ -f "$REPO_DIR/fonts/FiraCodeNerdFont-Regular.ttf" ]]; then
    success "FiraCode Nerd Font already bundled and copied"
fi

fc-cache -fv &>/dev/null
success "Font cache updated"

# ── Step 5: Oh My Zsh ─────────────────────────────────────────────────────────
step "Installing Oh My Zsh"

if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    info "Installing Oh My Zsh (unattended)..."
    RUNZSH=no KEEP_ZSHRC=yes \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
        "" --unattended
    success "Oh My Zsh installed"
else
    success "Oh My Zsh already installed"
fi

# ── Step 6: Powerlevel10k ─────────────────────────────────────────────────────
step "Installing Powerlevel10k"

P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [[ ! -d "$P10K_DIR" ]]; then
    info "Cloning Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
    success "Powerlevel10k installed"
else
    success "Powerlevel10k already installed"
fi

# ── Step 7: ZSH plugins ───────────────────────────────────────────────────────
step "Installing ZSH plugins"

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# zsh-autosuggestions
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
    info "Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions \
        "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    success "zsh-autosuggestions installed"
else
    success "zsh-autosuggestions already installed"
fi

# zsh-syntax-highlighting
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
    info "Installing zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting \
        "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
    success "zsh-syntax-highlighting installed"
else
    success "zsh-syntax-highlighting already installed"
fi

# ── Step 8: Backup existing configs ──────────────────────────────────────────
step "Backing up existing configs"

BACKUP_DIR="$HOME/.config.bak-arcos-$(date +%Y%m%d-%H%M%S)"
if [[ -d "$HOME/.config" ]]; then
    info "Backing up ~/.config to $BACKUP_DIR ..."
    cp -r "$HOME/.config" "$BACKUP_DIR"
    success "Config backed up"
fi

[[ -f "$HOME/.zshrc" ]]   && cp "$HOME/.zshrc"   "$HOME/.zshrc.bak-arcos"   && success ".zshrc backed up"
[[ -f "$HOME/.p10k.zsh" ]] && cp "$HOME/.p10k.zsh" "$HOME/.p10k.zsh.bak-arcos" && success ".p10k.zsh backed up"

# ── Step 9: Copy dotfiles ─────────────────────────────────────────────────────
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

# ZSH dotfiles
[[ -f "$REPO_DIR/zsh/.zshrc" ]]   && cp "$REPO_DIR/zsh/.zshrc"   "$HOME/.zshrc"   && success "Copied .zshrc"
[[ -f "$REPO_DIR/zsh/.p10k.zsh" ]] && cp "$REPO_DIR/zsh/.p10k.zsh" "$HOME/.p10k.zsh" && success "Copied .p10k.zsh"

# Make all scripts executable
chmod +x "$HOME/.config/hypr/scripts/"*.sh 2>/dev/null || true
success "Scripts made executable"

# Wallpapers
mkdir -p "$HOME/Pictures/Wallpapers"
if [[ -d "$REPO_DIR/assets/wallpapers" ]]; then
    cp "$REPO_DIR/assets/wallpapers/"* "$HOME/Pictures/Wallpapers/" 2>/dev/null || true
    success "Wallpapers copied"
fi

# ── Step 10: System configs ───────────────────────────────────────────────────
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

# ── Step 11: XDG user dirs ────────────────────────────────────────────────────
step "Setting up XDG user directories"

xdg-user-dirs-update --force
success "XDG user dirs created (Desktop, Downloads, Documents, Music, Pictures, Videos)"

# ── Step 12: Hibernate setup ──────────────────────────────────────────────────
step "Hibernate setup"

if [[ "$ENABLE_HIBERNATE" == "y" && -n "$DETECTED_SWAP_UUID" ]]; then
    info "Configuring hibernate with swap UUID: $DETECTED_SWAP_UUID"

    # Add resume= to systemd-boot entry
    BOOT_ENTRY=$(ls /boot/loader/entries/*.conf 2>/dev/null | head -1)
    if [[ -n "$BOOT_ENTRY" ]]; then
        if ! grep -q "resume=UUID=" "$BOOT_ENTRY"; then
            sudo sed -i "s/^options /options resume=UUID=$DETECTED_SWAP_UUID /" "$BOOT_ENTRY"
            success "resume= added to boot entry: $(basename "$BOOT_ENTRY")"
        else
            success "resume= already present in boot entry"
        fi
    else
        warn "No systemd-boot entry found — skipping bootloader modification"
    fi

    # Add resume hook to mkinitcpio
    if ! grep -q "resume" /etc/mkinitcpio.conf; then
        sudo sed -i 's/\(HOOKS=([^)]*filesystems\)/\1 resume/' /etc/mkinitcpio.conf
        success "resume hook added to mkinitcpio"
        sudo mkinitcpio -P
        success "initramfs rebuilt"
    else
        success "resume hook already present in mkinitcpio"
    fi
else
    info "Skipping hibernate setup"
fi

# ── Step 13: Enable services ──────────────────────────────────────────────────
step "Enabling services"

sudo systemctl enable sddm
success "sddm enabled"

sudo systemctl enable NetworkManager
success "NetworkManager enabled"

systemctl --user enable --now playerctld 2>/dev/null || true
success "playerctld enabled"

if [[ "$IS_LAPTOP" == "y" ]]; then
    sudo systemctl enable bluetooth
    success "bluetooth enabled"
fi

# ── Step 14: Set ZSH as default shell ─────────────────────────────────────────
step "Setting ZSH as default shell"

ZSH_PATH="$(which zsh)"
if [[ "$SHELL" != "$ZSH_PATH" ]]; then
    chsh -s "$ZSH_PATH" "$USER"
    success "Default shell set to ZSH"
else
    success "ZSH is already the default shell"
fi

# ── Step 15: Initial wallust run ──────────────────────────────────────────────
step "Running initial wallust"

FIRST_WALLPAPER=$(find "$HOME/Pictures/Wallpapers" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) | head -1)
if [[ -n "$FIRST_WALLPAPER" ]]; then
    mkdir -p "$HOME/.cache/wallust"
    wallust run "$FIRST_WALLPAPER" 2>/dev/null || true
    echo "$FIRST_WALLPAPER" > "$HOME/.cache/wallust/wallpaper"
    success "wallust initialized with: $(basename "$FIRST_WALLPAPER")"
else
    warn "No wallpapers found in ~/Pictures/Wallpapers — wallust skipped"
fi

# ── Step 16: Timeshift setup ──────────────────────────────────────────────────
step "Setting up Timeshift"

sudo systemctl enable --now cronie 2>/dev/null || true
info "Timeshift installed. Configure your first snapshot after reboot via: timeshift-gtk"

# ── Step 17: Pacman cache cleanup ─────────────────────────────────────────────
step "Cleaning up"

paccache -rk2 2>/dev/null || true
rm -rf /tmp/arcos-* 2>/dev/null || true
success "Cache cleaned"

# ── Done ──────────────────────────────────────────────────────────────────────
clear
echo -e "${CYAN}${BOLD}"
cat << 'EOF'
    ___             ____  _____
   /   |  __________/ __ \/ ___/
  / /| | / ___/ ___/ / / /\__ \
 / ___ |/ /  / /__/ /_/ /___/ /
/_/  |_/_/   \___/\____//____/

         Install complete!
EOF
echo -e "${RESET}"
echo -e "${BOLD}  Keybinds cheatsheet:${RESET}"
echo -e "  ${CYAN}Super + Enter${RESET}       Terminal (kitty)"
echo -e "  ${CYAN}Super + Space${RESET}       App launcher (rofi)"
echo -e "  ${CYAN}Super + E${RESET}           File manager (Thunar)"
echo -e "  ${CYAN}Super + W${RESET}           Wallpaper picker"
echo -e "  ${CYAN}Super + Shift+W${RESET}     Toggle dark/light mode"
echo -e "  ${CYAN}Super + L${RESET}           Lock screen"
echo -e "  ${CYAN}Super + X${RESET}           Power menu"
echo -e "  ${CYAN}Super + N${RESET}           Notification center"
echo -e "  ${CYAN}Super + V${RESET}           Clipboard history"
echo -e "  ${CYAN}Super + .${RESET}           Emoji picker"
echo -e "  ${CYAN}Super + Q${RESET}           Close window"
echo -e "  ${CYAN}Print${RESET}               Screenshot (region)"
echo ""
echo -e "${YELLOW}${BOLD}  ⚠  Please reboot to complete the setup.${RESET}"
echo -e "     ${BOLD}sudo reboot${RESET}\n"
