#!/usr/bin/env bash

# ─── Options ─────────────────────────────────────────────────────────
shutdown="󰐥  Shutdown"
reboot="󰜉  Reboot"
suspend="󰤄  Suspend"
hibernate="󰒲  Hibernate"
lock="󰌾  Lock"
logout="󰍃  Logout"

# ─── Rofi menu ───────────────────────────────────────────────────────
chosen=$(echo -e "$lock\n$suspend\n$hibernate\n$logout\n$reboot\n$shutdown" | rofi \
    -dmenu \
    -i \
    -p "  Power" \
    -theme "~/.config/rofi/themes/launcher.rasi" \
    -theme-str '
        window {
            width: 220px;
            y-offset: 52px;
        }
        listview {
            lines: 6;
            columns: 1;
            spacing: 4px;
        }
        element-icon { enabled: false; }
        inputbar { enabled: false; }
        mode-switcher { enabled: false; }
    ')

# ─── Actions ─────────────────────────────────────────────────────────
case "$chosen" in
    "$shutdown")   systemctl poweroff ;;
    "$reboot")     systemctl reboot ;;
    "$suspend")    systemctl suspend ;;
    "$hibernate")  systemctl hibernate ;;
    "$lock")       hyprlock ;;
    "$logout")     hyprctl dispatch exit ;;
esac
