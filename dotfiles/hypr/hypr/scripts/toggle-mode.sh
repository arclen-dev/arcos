#!/usr/bin/env bash

CURRENT=$(gsettings get org.gnome.desktop.interface color-scheme)

if [[ "$CURRENT" == "'prefer-dark'" ]]; then
    # Switch to light
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3'
    gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Light'
    sed -i 's/palette = "dark16"/palette = "light16"/' ~/.config/wallust/wallust.toml
else
    # Switch to dark
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'
    gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
    sed -i 's/palette = "light16"/palette = "dark16"/' ~/.config/wallust/wallust.toml
fi

# Re-run wallust with current wallpaper to regenerate all color templates
LAST=$(cat ~/.cache/wallust/wallpaper 2>/dev/null)
[ -f "$LAST" ] && wallust run "$LAST"

~/.config/hypr/scripts/update-hyprlock-colors.sh

# Reload everything
pkill waybar && sleep 0.3 && waybar &
pkill -SIGUSR1 kitty
hyprctl reload
