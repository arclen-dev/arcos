#!/usr/bin/env bash
# =============================================================================
#  ArcOS Uninstaller
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

info()    { echo -e "  ${CYAN}${BOLD}➜${RESET}  $*"; }
success() { echo -e "  ${GREEN}${BOLD}✔${RESET}  $*"; }
warn()    { echo -e "  ${YELLOW}${BOLD}!${RESET}  ${YELLOW}$*${RESET}"; }
error()   { echo -e "\n  ${RED}${BOLD}✘  ERROR:${RESET} $*\n"; exit 1; }

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
echo -e "  ${WHITE}${BOLD}ArcOS Uninstaller${RESET}  ${DIM}by arclen-dev${RESET}"
echo -e "  ${DIM}────────────────────────────────────────${RESET}\n"
echo -e "  ${YELLOW}${BOLD}This will remove ArcOS dotfiles and attempt to restore your backup.${RESET}\n"

[[ "$EUID" -eq 0 ]] && error "Do not run as root."
[[ -f /etc/arch-release ]] || error "This uninstaller requires an Arch-based distro."

LATEST_BACKUP=$(ls -dt "$HOME"/.config.bak-arcos-* 2>/dev/null | head -1)

if [[ -z "$LATEST_BACKUP" ]]; then
    warn "No ArcOS backup found at ~/.config.bak-arcos-*"
    warn "Dotfiles will be removed but nothing will be restored."
    echo ""
    read -rp "  Continue anyway? [y/N]: " CONFIRM
    [[ "${CONFIRM,,}" != "y" ]] && { info "Uninstall cancelled."; exit 0; }
    RESTORE=false
else
    info "Found backup: ${BOLD}$LATEST_BACKUP${RESET}"
    read -rp "  Restore this backup? [Y/n]: " CONFIRM_RESTORE
    [[ "${CONFIRM_RESTORE,,}" == "n" ]] && RESTORE=false || RESTORE=true
fi

echo ""
read -rp "  Proceed with uninstall? Press Enter to continue or Ctrl+C to cancel... "

# Remove ArcOS dotfiles
echo ""
info "Removing ArcOS dotfiles..."

DOTFILES=(hypr waybar rofi kitty swaync hypridle wallust btop fresh gtk-3.0 gtk-4.0 nwg-look geany qt6ct fish)
for folder in "${DOTFILES[@]}"; do
    if [[ -d "$HOME/.config/$folder" ]]; then
        rm -rf "$HOME/.config/$folder"
        success "Removed ~/.config/$folder"
    fi
done

# Remove generated hyprlock cache
rm -rf "$HOME/.cache/arcos" && success "Removed ~/.cache/arcos"

[[ -d "$HOME/Pictures/Wallpapers" ]] && rm -rf "$HOME/Pictures/Wallpapers" && success "Removed ~/Pictures/Wallpapers"

# Remove sddm-silent-theme
echo ""
info "Removing sddm-silent-theme..."
yay -Rns --noconfirm sddm-silent-theme 2>/dev/null && success "sddm-silent-theme removed" || warn "sddm-silent-theme not found"
sudo rm -rf /usr/share/sddm/themes/silent 2>/dev/null || true
if [[ -f /etc/sddm.conf ]]; then
    sudo sed -i '/^Current=silent/d'                         /etc/sddm.conf
    sudo sed -i '/^InputMethod=qtvirtualkeyboard/d'          /etc/sddm.conf
    success "sddm.conf reverted"
fi

# Restore backup
if [[ "${RESTORE:-false}" == true ]]; then
    echo ""
    info "Restoring backup from $LATEST_BACKUP ..."
    for folder in "$LATEST_BACKUP"/*/; do
        name=$(basename "$folder")
        cp -r "$folder" "$HOME/.config/$name"
        success "Restored ~/.config/$name"
    done
    sudo rm -f /etc/sysctl.d/99-swappiness.conf 2>/dev/null && success "swappiness config removed (default restored on reboot)"
else
    info "No backup — removing ArcOS-installed items..."
    rm -rf "$HOME/.local/share/fonts/Inter"* "$HOME/.local/share/fonts/FiraCode"* \
           "$HOME/.local/share/fonts/Orbitron"* 2>/dev/null && success "ArcOS fonts removed" || true
    sudo rm -f /etc/sysctl.d/99-swappiness.conf 2>/dev/null && success "swappiness config removed" || true
fi

# Revert shell
echo ""
read -rp "  Revert default shell back to bash? [y/N]: " REVERT_SHELL
if [[ "${REVERT_SHELL,,}" == "y" ]]; then
    chsh -s /bin/bash "$USER" && success "Shell reverted to bash"
fi

# Disable services
echo ""
read -rp "  Disable ArcOS-enabled services (sddm, NetworkManager)? [y/N]: " DISABLE_SERVICES
if [[ "${DISABLE_SERVICES,,}" == "y" ]]; then
    sudo systemctl disable sddm                  2>/dev/null && success "sddm disabled"                  || warn "sddm not found"
    sudo systemctl disable NetworkManager        2>/dev/null && success "NetworkManager disabled"        || warn "NM not found"
    sudo systemctl disable bluetooth             2>/dev/null && success "bluetooth disabled"             || true
    sudo systemctl disable power-profiles-daemon 2>/dev/null && success "power-profiles-daemon disabled" || true
    sudo systemctl disable acpid                 2>/dev/null && success "acpid disabled"                 || true
fi

echo ""
echo -e "  ${GREEN}${BOLD}✔  ArcOS uninstalled.${RESET}"
[[ "${RESTORE:-false}" == true ]] && echo -e "  ${DIM}Your previous config has been restored.${RESET}"
echo -e "  ${YELLOW}Reboot recommended: ${BOLD}sudo reboot${RESET}"
echo ""
