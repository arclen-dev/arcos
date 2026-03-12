#!/usr/bin/env bash
# Wallpaper selector: Rofi with thumbnail preview → swww → wallust → refresh all

WALL_DIR="$HOME/Pictures/Wallpapers"
CACHE_DIR="$HOME/.cache/wallust-thumbs"
mkdir -p "$CACHE_DIR"

# --- Build entry list ---
MENU=""
MENU+="  Random Wallpaper\0icon\x1f/usr/share/icons/Papirus-Dark/24x24/actions/object-tweak-randomize.svg\n"

while IFS= read -r img; do
    name=$(basename "$img")
    MENU+="$name\0icon\x1f$img\n"
done < <(find "$WALL_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" \
    -o -iname "*.png" -o -iname "*.webp" \) | sort)

# --- Show rofi menu ---
SELECTION=$(printf "%b" "$MENU" | rofi -dmenu \
    -i \
    -p "Wallpaper" \
    -show-icons \
    -theme "~/.config/rofi/themes/launcher.rasi" \
    -theme-str '
        window {
            width: 900px;
            height: 600px;
            y-offset: 52px;
        }
        listview {
            columns:      4;
            lines:        20;
            scrollbar:    true;
            spacing:      4px;
            padding:      4px;
            fixed-height: true;
        }
        element {
            padding:      4px;
            spacing:      4px;
            border-radius: 8px;
            orientation:  vertical;
        }
        element-icon { size: 160px; }
        element-text {
            enabled:          true;
            font:             "Inter 9";
            vertical-align:   0.5;
            horizontal-align: 0.5;
        }
    ')

# Exit if nothing selected
[ -z "$SELECTION" ] && exit 0

# --- Handle random selection ---
if [[ "$SELECTION" == "  Random Wallpaper" ]]; then
    WALLPAPER=$(find "$WALL_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" \
        -o -iname "*.png" -o -iname "*.webp" \) | shuf -n 1)
else
    WALLPAPER="$WALL_DIR/$SELECTION"
fi

[ -z "$WALLPAPER" ] && exit 0

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

# --- Update sddm wallpaper ---
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
