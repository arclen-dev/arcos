#!/usr/bin/env bash
# Restore last wallpaper on Hyprland start
LAST=$(cat ~/.cache/wallust/wallpaper 2>/dev/null)
if [ -f "$LAST" ]; then
    awww img "$LAST" --transition-type none
    wallust run "$LAST"
fi