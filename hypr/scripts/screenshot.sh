#!/usr/bin/env bash
# Wayland screenshot helper.
#
#   screenshot.sh <region|screen|window> [annotate]
#
# Without `annotate`: grim writes a PNG to ~/Pictures/Screenshots/ and
# copies it to the Wayland clipboard (cliphist's watcher stores it too).
#
# With `annotate`: the captured PNG is piped into satty (arrows / text /
# blur). On save, satty writes the annotated PNG to the same directory
# and copies it to the clipboard via wl-copy.

set -euo pipefail

mode="${1:-region}"
annotate="${2:-}"

dest_dir="$HOME/Pictures/Screenshots"
mkdir -p "$dest_dir"
out="$dest_dir/$(date +%Y-%m-%d_%H-%M-%S).png"

case "$mode" in
    region) geom="$(slurp -d)" ;;
    screen) geom="$(hyprctl -j monitors     | jq -r '.[] | select(.focused) | "\(.x),\(.y) \(.width)x\(.height)"')" ;;
    window) geom="$(hyprctl -j activewindow | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')" ;;
    *)
        echo "usage: $0 <region|screen|window> [annotate]" >&2
        exit 2
        ;;
esac

if [[ "$annotate" == "annotate" ]] && command -v satty >/dev/null 2>&1; then
    grim -g "$geom" - | satty \
        --filename - \
        --output-filename "$out" \
        --copy-command wl-copy \
        --early-exit \
        --initial-tool brush
    notify-send -a "screenshot" "Annotated screenshot saved" "$out"
else
    grim -g "$geom" "$out"
    wl-copy < "$out"
    notify-send -a "screenshot" "Screenshot saved" "$out (also on clipboard)"
fi
