#!/usr/bin/env bash
# Floating kitty window running pulsemixer — minimal Catppuccin TUI mixer
# with per-app volume control. Window rule (`hypr-audio-popup`) sizes
# and centers it; ESC inside pulsemixer closes the window.
#
# Toggle: opening it twice closes the existing instance.

set -euo pipefail

if hyprctl -j clients | grep -q '"class": "hypr-audio-popup"'; then
    hyprctl dispatch closewindow class:hypr-audio-popup
    exit 0
fi

exec kitty \
    --class hypr-audio-popup \
    --title "audio mixer" \
    --override "background_opacity=0.85" \
    --override "font_size=12" \
    -- pulsemixer
