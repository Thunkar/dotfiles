#!/usr/bin/env bash
# Build a keybind cheatsheet by parsing `# @cheat: <category> | <desc>`
# trailing comments from the hypr config and showing them in a floating
# kitty window (matched by the `hypr-cheatsheet` window rule).
set -euo pipefail

CONF_DIR="${HOME}/.config/hypr/conf.d"

# Toggle: if a cheatsheet window is already open, close it instead.
if hyprctl -j clients | grep -q '"class": "hypr-cheatsheet"'; then
    hyprctl dispatch closewindow class:hypr-cheatsheet
    exit 0
fi

tmp=$(mktemp --suffix=.txt)
trap 'rm -f "$tmp"' EXIT

{
    printf "  HYPR  •  KEYBIND CHEATSHEET\n"
    printf "  ─────────────────────────────────────────────────────────────\n\n"

    # Parse:  bind = MOD, KEY, action ... # @cheat: category | description
    # Group by category, preserve declaration order within a category.
    awk -F'@cheat:' '
        /^[ \t]*bind[a-z]*[ \t]*=.*@cheat:/ {
            # Left side: bind = ... (keep MOD, KEY)
            left = $1
            # Right side: " category | description"
            right = $2
            sub(/^[ \t]+/, "", right)
            split(right, p, "|")
            cat  = p[1]; sub(/[ \t]+$/, "", cat); sub(/^[ \t]+/, "", cat)
            desc = p[2]; sub(/^[ \t]+/, "", desc); sub(/[ \t]+$/, "", desc)

            # Extract keys: text between first "=" and the action
            # e.g. "bind = $mainMod, Q, exec, kitty" -> "$mainMod + Q"
            n = split(left, fields, ",")
            # fields[1] = "bind = $mainMod" (or similar)
            mod = fields[1]; sub(/^[^=]*=[ \t]*/, "", mod); sub(/[ \t]+$/, "", mod)
            key = fields[2]; sub(/^[ \t]+/, "", key); sub(/[ \t]+$/, "", key)
            if (mod == "" || mod == " ") combo = key
            else combo = mod " + " key
            gsub(/\$mainMod/, "SUPER", combo)
            gsub(/SHIFT/, "Shift", combo)
            gsub(/ALT/, "Alt",   combo)
            gsub(/CTRL/, "Ctrl", combo)

            order[cat]++
            entries[cat, order[cat], "key"]  = combo
            entries[cat, order[cat], "desc"] = desc
            if (!(cat in seen)) { seen[cat]=1; cats[++ncats]=cat }
        }
        END {
            for (i = 1; i <= ncats; i++) {
                c = cats[i]
                printf "  ▸ %s\n", toupper(c)
                for (j = 1; j <= order[c]; j++) {
                    printf "      %-28s  %s\n", entries[c,j,"key"], entries[c,j,"desc"]
                }
                printf "\n"
            }
        }
    ' "$CONF_DIR"/*.conf

    printf "  ─────────────────────────────────────────────────────────────\n"
    printf "  Press q or Esc to close.\n"
} > "$tmp"

# Spawn kitty with the matching class (window rule centers and sizes it).
exec kitty \
    --class hypr-cheatsheet \
    --title "Hypr cheatsheet" \
    --override "background_opacity=0.85" \
    --override "font_size=12" \
    -- less -R "$tmp"
