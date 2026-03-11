#!/usr/bin/env bash
# Syncs current wallpaper to SDDM theme background
WALLPAPER=$(cat ~/.cache/wallust/wallpaper 2>/dev/null)
[ -f "$WALLPAPER" ] && sudo cp "$WALLPAPER" /usr/share/sddm/themes/arclen/background.jpg
