#!/usr/bin/env bash
# Floating kitty window running bluetuith — TUI Bluetooth manager that
# matches the rest of the system's Catppuccin terminal aesthetic.
# Right-click on the waybar bluetooth pill opens blueman-manager for
# everything that doesn't fit in a TUI (audio profile sinks, OBEX, …).

set -euo pipefail

if hyprctl -j clients | grep -q '"class": "hypr-bt-popup"'; then
    hyprctl dispatch closewindow class:hypr-bt-popup
    exit 0
fi

# Make sure the controller is powered before launching the TUI; bluetuith
# refuses to render device lists with the adapter off.
if command -v bluetoothctl >/dev/null 2>&1; then
    bluetoothctl show 2>/dev/null | grep -q "Powered: yes" || bluetoothctl power on >/dev/null 2>&1 || true
fi

exec kitty \
    --class hypr-bt-popup \
    --title "bluetooth" \
    --override "background_opacity=0.85" \
    --override "font_size=12" \
    -- bluetuith
