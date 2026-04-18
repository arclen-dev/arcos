#!/usr/bin/env bash
# Toggle between dark and light mode

CURRENT=$(gsettings get org.gnome.desktop.interface color-scheme)

if [[ "$CURRENT" == "'prefer-dark'" ]]; then
    gsettings set org.gnome.desktop.interface color-scheme  'prefer-light'
    gsettings set org.gnome.desktop.interface gtk-theme     'adw-gtk3'
    gsettings set org.gnome.desktop.interface icon-theme    'Papirus-Light'
    sed -i 's/palette = "dark16"/palette = "light16"/' ~/.config/wallust/wallust.toml
else
    gsettings set org.gnome.desktop.interface color-scheme  'prefer-dark'
    gsettings set org.gnome.desktop.interface gtk-theme     'adw-gtk3-dark'
    gsettings set org.gnome.desktop.interface icon-theme    'Papirus-Dark'
    sed -i 's/palette = "light16"/palette = "dark16"/' ~/.config/wallust/wallust.toml
fi

# Re-run wallust with current wallpaper to regenerate all color templates
LAST=$(cat ~/.cache/wallust/wallpaper 2>/dev/null)
[ -f "$LAST" ] && wallust run "$LAST"

# Regenerate hyprlock dynamic config with updated colors
~/.config/hypr/scripts/hyprlock-gen.sh --now

# Reload everything
pkill waybar && sleep 0.3 && waybar &
pkill -SIGUSR1 kitty 2>/dev/null || true
hyprctl reload
