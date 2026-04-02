#!/usr/bin/env bash
# =============================================================================
#  ArcOS MPRIS Marquee Scroller
#  Outputs scrolling now-playing text for waybar custom module
# =============================================================================

SCROLL_SPEED=0.3   # seconds per step
MAX_LEN=25         # visible characters
SEP="   ·   "      # separator between loops

get_status() {
    playerctl status 2>/dev/null
}

get_text() {
    local status=$(get_status)
    local title artist icon

    case "$status" in
        Playing)
            title=$(playerctl metadata title 2>/dev/null | head -c 60)
            artist=$(playerctl metadata artist 2>/dev/null | head -c 40)
            # Pick icon based on player name
            local player=$(playerctl -l 2>/dev/null | head -1)
            case "$player" in
                *spotify*) icon="" ;;
                *firefox*) icon="" ;;
                *mpv*)     icon="󰐹" ;;
                *vlc*)     icon="󰕼" ;;
                *)         icon="" ;;
            esac
            if [[ -n "$artist" ]]; then
                echo "${icon} ${title} — ${artist}"
            else
                echo "${icon} ${title}"
            fi
            ;;
        Paused)
            title=$(playerctl metadata title 2>/dev/null | head -c 60)
            echo "󰏤 ${title}"
            ;;
        *)
            echo ""
            ;;
    esac
}

# State file to track scroll position
POS_FILE="/tmp/arcos-mpris-pos"
LAST_TRACK_FILE="/tmp/arcos-mpris-track"

pos=0

while true; do
    status=$(get_status)

    if [[ "$status" != "Playing" && "$status" != "Paused" ]]; then
        echo ""
        pos=0
        sleep 1
        continue
    fi

    text=$(get_text)
    full="${text}${SEP}"
    len=${#full}

    # Reset position if track changed
    current_track=$(playerctl metadata title 2>/dev/null)
    last_track=$(cat "$LAST_TRACK_FILE" 2>/dev/null)
    if [[ "$current_track" != "$last_track" ]]; then
        pos=0
        echo "$current_track" > "$LAST_TRACK_FILE"
    fi

    # If text is short enough, just show it statically
    if [[ ${#text} -le $MAX_LEN ]]; then
        echo "$text"
        sleep 1
        continue
    fi

    # Slice the visible window
    doubled="${full}${full}"
    visible="${doubled:$pos:$MAX_LEN}"
    echo "$visible"

    # Advance position
    pos=$(( (pos + 1) % len ))

    sleep "$SCROLL_SPEED"
done
