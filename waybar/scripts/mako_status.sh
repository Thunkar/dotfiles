#!/usr/bin/env bash
# Waybar custom module: shows mako mode (DND vs default) and toggles on click.
#
# Icon bytes are emitted via printf with explicit \x escapes so they
# survive any pipeline that's prone to dropping multibyte chars in
# string literals (we've been bitten by this before).
set -euo pipefail

# U+F0F3 — FontAwesome solid bell  (notifications on)
BELL_ON=$'\xef\x83\xb3'
# U+F1F6 — FontAwesome bell-slash  (notifications off / DND)
BELL_OFF=$'\xef\x87\xb6'

if [[ "${1:-}" == "toggle" ]]; then
    current=$(makoctl mode 2>/dev/null | head -n1 || echo default)
    if [[ "$current" == "do-not-disturb" ]]; then
        makoctl mode -s default
    else
        makoctl mode -s do-not-disturb
    fi
    exit 0
fi

mode=$(makoctl mode 2>/dev/null | head -n1 || echo default)
case "$mode" in
    do-not-disturb) text="$BELL_OFF"; class="dnd"; tip="Notifications muted (DND)" ;;
    *)              text="$BELL_ON";  class="on";  tip="Notifications on" ;;
esac
printf '{"text":"%s","class":"%s","tooltip":"%s"}\n' "$text" "$class" "$tip"
