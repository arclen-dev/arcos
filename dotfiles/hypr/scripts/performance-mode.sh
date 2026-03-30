#!/usr/bin/env bash
# =============================================================================
#  ArcOS Performance Mode Toggle
#  Super + P to toggle on/off
# =============================================================================

STATE_FILE="$HOME/.cache/arcos-perf-mode"

enable_performance() {
    # ── Animations off ────────────────────────────────────────────────────────
    hyprctl keyword animations:enabled false

    # ── Blur off ──────────────────────────────────────────────────────────────
    hyprctl keyword decoration:blur:enabled false

    # ── Shadow off ────────────────────────────────────────────────────────────
    hyprctl keyword decoration:shadow:enabled false

    # ── Inactive opacity to 1.0 (no transparency) ─────────────────────────────
    hyprctl keyword decoration:inactive_opacity 1.0

    # ── Rounding off ──────────────────────────────────────────────────────────
    hyprctl keyword decoration:rounding 0

    # Mark state
    touch "$STATE_FILE"

    notify-send -u normal -i "/usr/share/icons/Papirus-Dark/48x48/actions/media-playback-start.svg" \
        "Performance Mode" "Animations, blur and shadows disabled" -t 3000
}

disable_performance() {
    # ── Restore animations ────────────────────────────────────────────────────
    hyprctl keyword animations:enabled true

    # ── Restore blur ──────────────────────────────────────────────────────────
    hyprctl keyword decoration:blur:enabled true
    hyprctl keyword decoration:blur:size 3
    hyprctl keyword decoration:blur:passes 1
    hyprctl keyword decoration:blur:vibrancy 0.1696

    # ── Restore shadow ────────────────────────────────────────────────────────
    hyprctl keyword decoration:shadow:enabled true
    hyprctl keyword decoration:shadow:range 4
    hyprctl keyword decoration:shadow:render_power 3

    # ── Restore opacity ───────────────────────────────────────────────────────
    hyprctl keyword decoration:inactive_opacity 0.9

    # ── Restore rounding ──────────────────────────────────────────────────────
    hyprctl keyword decoration:rounding 8

    # Remove state
    rm -f "$STATE_FILE"

    notify-send -u normal -i "/usr/share/icons/Papirus-Dark/48x48/actions/media-playback-stop.svg" \
        "Normal Mode" "Animations, blur and shadows restored" -t 3000
}

# ── Toggle based on state file ────────────────────────────────────────────────
if [[ -f "$STATE_FILE" ]]; then
    disable_performance
else
    enable_performance
fi
