#!/usr/bin/env bash
# Wofi-driven clipboard picker for cliphist.
#
# Usage:
#   cliphist-pick.sh           pick an item, decode it, push back to clipboard
#   cliphist-pick.sh delete    pick an item and remove it from history
#   cliphist-pick.sh wipe      clear the entire clipboard history
#
# cliphist stores binary blobs (PNG screenshots etc.) too. wofi can't
# render image previews from binary, but cliphist annotates image
# entries as `[[ binary data: 12345 bytes png ]]` so they're at least
# identifiable in the picker.

set -euo pipefail

WOFI_ARGS=(--dmenu --width 640 --height 500 --location center --prompt clipboard --insensitive)

case "${1:-pick}" in
    delete)
        cliphist list \
            | wofi "${WOFI_ARGS[@]}" --prompt "delete from clipboard" \
            | cliphist delete
        ;;
    wipe)
        cliphist wipe
        notify-send -a clipboard "Clipboard history wiped"
        ;;
    pick|*)
        cliphist list \
            | wofi "${WOFI_ARGS[@]}" \
            | cliphist decode \
            | wl-copy
        ;;
esac
