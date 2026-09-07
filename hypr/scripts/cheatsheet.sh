#!/usr/bin/env bash
# Keybind cheatsheet, generated from the running compositor.
#
# Every bind declared with a description of the form "category | text"
# (see conf/keybinds.lua) is read back via `hyprctl binds -j`, grouped by
# category in declaration order, and shown in a floating kitty window
# (matched by the hypr-cheatsheet window rule). No config parsing involved.
set -euo pipefail

# Toggle: if a cheatsheet window is already open, close it instead.
if hyprctl -j clients | jq -e 'any(.[]; .class == "hypr-cheatsheet")' >/dev/null; then
    hyprctl dispatch closewindow class:hypr-cheatsheet
    exit 0
fi

tmp=$(mktemp --suffix=.txt)
trap 'rm -f "$tmp"' EXIT

{
    printf "  HYPR  •  KEYBIND CHEATSHEET\n"
    printf "  ─────────────────────────────────────────────────────────────\n\n"

    # jq: decode the modifier bitmask, emit "category<TAB>combo<TAB>text".
    hyprctl -j binds | jq -r '
        def bit($b): ((.modmask / $b) | floor) % 2 == 1;
        .[]
        | select(.has_description and (.description | contains(" | ")))
        | (.description | split(" | ")) as $d
        | ([ (if bit(64) then "SUPER" else empty end),
             (if bit(4)  then "Ctrl"  else empty end),
             (if bit(8)  then "Alt"   else empty end),
             (if bit(1)  then "Shift" else empty end),
             .key ] | join(" + ")) as $combo
        | [$d[0], $combo, $d[1]] | @tsv' \
    | awk -F'\t' '
        {
            if (!($1 in seen)) { seen[$1] = 1; cats[++n] = $1 }
            count[$1]++
            key[$1, count[$1]]  = $2
            desc[$1, count[$1]] = $3
        }
        END {
            if (n == 0) {
                print "  No described binds found. Is Hyprland running the Lua config yet?"
                print "  (log out and back in after migrating from hyprland.conf)"
                exit
            }
            for (i = 1; i <= n; i++) {
                c = cats[i]
                printf "  ▸ %s\n", toupper(c)
                for (j = 1; j <= count[c]; j++)
                    printf "      %-28s  %s\n", key[c, j], desc[c, j]
                printf "\n"
            }
        }'

    printf "  ─────────────────────────────────────────────────────────────\n"
    printf "  Press q to close.\n"
} > "$tmp"

exec kitty \
    --class hypr-cheatsheet \
    --title "Hypr cheatsheet" \
    --override "background_opacity=0.85" \
    --override "font_size=12" \
    -- less -R "$tmp"
