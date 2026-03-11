#!/usr/bin/env bash
# Read color4 and color5 from generated wallust waybar CSS
COLOR4=$(grep "color4" ~/.config/waybar/wallust/colors-waybar.css | sed 's/.*#//' | sed 's/;//' | tr -d ' ')
COLOR5=$(grep "color5" ~/.config/waybar/wallust/colors-waybar.css | sed 's/.*#//' | sed 's/;//' | tr -d ' ')

# Convert hex to r,g,b
r4=$((16#${COLOR4:0:2}))
g4=$((16#${COLOR4:2:2}))
b4=$((16#${COLOR4:4:2}))

r5=$((16#${COLOR5:0:2}))
g5=$((16#${COLOR5:2:2}))
b5=$((16#${COLOR5:4:2}))

# Update hyprlock config
sed -i "s/color       = rgba([0-9]*, [0-9]*, [0-9]*, 0.95)/color       = rgba($r4, $g4, $b4, 0.95)/" ~/.config/hypr/hyprlock.conf
# Second label (minutes) needs separate handling
sed -i "0,/rgba($r4, $g4, $b4, 0.95)/! s/rgba([0-9]*, [0-9]*, [0-9]*, 0.95)/rgba($r5, $g5, $b5, 0.95)/" ~/.config/hypr/hyprlock.conf
