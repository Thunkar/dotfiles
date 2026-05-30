#!/usr/bin/env bash
# Wayland screenshot helper.
#
#   screenshot.sh <region|screen|window> [annotate]
#
# Without `annotate`: grim writes a PNG to ~/Pictures/Screenshots/ and
# also copies it to the Wayland clipboard (CopyQ picks it up
# automatically and stores it in history with a thumbnail).
#
# With `annotate`: the captured PNG is piped into satty, an editor for
# arrows / text / blur. On save, satty writes the annotated PNG to
# the same screenshots dir and copies it to the clipboard via wl-copy.

set -euo pipefail

mode="${1:-region}"
annotate="${2:-}"

dest_dir="$HOME/Pictures/Screenshots"
mkdir -p "$dest_dir"
out="$dest_dir/$(date +%Y-%m-%d_%H-%M-%S).png"

geom=""
case "$mode" in
    region)
        geom="$(slurp -d)"
        ;;
    screen)
        geom="$(hyprctl monitors -j | python3 -c '
import json, sys
mon = next(m for m in json.load(sys.stdin) if m["focused"])
print(f"{mon[\"x\"]},{mon[\"y\"]} {mon[\"width\"]}x{mon[\"height\"]}")')"
        ;;
    window)
        geom="$(hyprctl activewindow -j | python3 -c '
import json, sys
w = json.load(sys.stdin)
x, y = w["at"]; W, H = w["size"]
print(f"{x},{y} {W}x{H}")')"
        ;;
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
