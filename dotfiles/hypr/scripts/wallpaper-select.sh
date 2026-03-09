#!/usr/bin/env bash
# Wallpaper selector: Rofi with thumbnail preview → swww → wallust → refresh all

WALL_DIR="$HOME/Pictures/Wallpapers"
CACHE_DIR="$HOME/.cache/wallust-thumbs"
mkdir -p "$CACHE_DIR"

# --- Build the Rofi menu with image thumbnails ---
SELECTION=$(find "$WALL_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" \
    -o -iname "*.png" -o -iname "*.webp" \) | sort | while read -r img; do
    name=$(basename "$img")
    echo -en "$name\0icon\x1f$img\n"
done | rofi -dmenu \
    -i \
    -p "Wallpaper" \
    -show-icons \
    -theme "/home/arclen/.config/rofi/themes/launcher.rasi" \
    -theme-str '
        window {
            width: 900px;
            height: 600px;
            y-offset: 52px;
        }
        listview {
            columns: 4;
            lines: 3;
            spacing: 4px;
            padding: 4px;
        }
        element {
            padding: 4px;
            spacing: 4px;
            border-radius: 8px;
            orientation: vertical;
        }
        element-icon { size: 160px; }
        element-text { enabled: true; font: "Inter 9"; vertical-align: 0.5; horizontal-align: 0.5; }
    ' \
)

# Exit if nothing selected
[ -z "$SELECTION" ] && exit 0

WALLPAPER="$WALL_DIR/$SELECTION"

# --- Apply wallpaper with swww transition ---
swww img "$WALLPAPER" \
    --transition-type wipe \
    --transition-angle 30 \
    --transition-duration 1.5 \
    --transition-fps 60

# --- Run wallust to generate new color templates ---
wallust run "$WALLPAPER"

# --- Save wallpaper path for restore and toggle scripts ---
echo "$WALLPAPER" > ~/.cache/wallust/wallpaper

# --- Update hyprlock colors ---
~/.config/hypr/scripts/update-hyprlock-colors.sh

# --- Update sddm wallpaper---
~/.config/hypr/scripts/sync-sddm-wallpaper.sh

# --- Restart Waybar to apply new CSS colors ---
pkill waybar
sleep 0.5
waybar &

# --- Reload Kitty with new colors (no restart needed) ---
pkill -SIGUSR1 kitty

# --- Reload Hyprland config for border colors ---
hyprctl reload

echo "Wallpaper set: $WALLPAPER"
