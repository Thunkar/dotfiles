#!/usr/bin/env bash
# Caffeine for Hyprland: pauses the idle daemon (hypridle.service, a systemd
# user unit) for a chosen duration.
#
#   caffeine.sh                  emit waybar JSON state
#   caffeine.sh status           (alias of the no-arg form)
#   caffeine.sh on <duration>    stop hypridle for <duration>, auto-revert
#   caffeine.sh off              start hypridle again now
#   caffeine.sh toggle [dur]     off → on:<dur>, on → off  (dur defaults 30min)
#   caffeine.sh menu             wofi picker over preset durations
#
# <duration> is anything systemd accepts (30min, 2h, 5h) OR the literal
# word "forever". The auto-revert is a transient user timer
# (caffeine-revert.timer) that simply starts hypridle.service again;
# turning caffeine off cancels it.

set -euo pipefail

ICON=$'\xef\x83\xb4'    # nf-fa-coffee
IDLE_UNIT="hypridle.service"
REVERT="caffeine-revert"

is_caffeinated() { ! systemctl --user is-active --quiet "$IDLE_UNIT"; }

cancel_revert() {
    systemctl --user stop "$REVERT.timer" "$REVERT.service" 2>/dev/null || true
}

revert_in() {
    cancel_revert
    systemd-run --user --quiet \
        --unit="$REVERT" \
        --on-active="$1" \
        --description="caffeine auto-revert" \
        systemctl --user start "$IDLE_UNIT"
}

remaining_label() {
    # "Xh Ym left" while a revert timer is scheduled, "forever" otherwise.
    local next ts now diff h m
    next=$(systemctl --user show "$REVERT.timer" -p NextElapseUSecRealtime --value 2>/dev/null || true)
    if [[ -z "$next" || "$next" == "n/a" ]]; then
        is_caffeinated && echo "forever" || echo ""
        return
    fi
    ts=$(date -d "$next" +%s 2>/dev/null || echo 0)
    (( ts == 0 )) && { echo "forever"; return; }
    now=$(date +%s)
    diff=$(( ts - now )); (( diff < 0 )) && diff=0
    h=$(( diff / 3600 )); m=$(( (diff % 3600) / 60 ))
    if (( h > 0 )); then echo "${h}h ${m}m left"; else echo "${m}m left"; fi
}

on_for() {
    local dur="$1"
    systemctl --user stop "$IDLE_UNIT" 2>/dev/null || true
    if [[ "$dur" == "forever" ]]; then
        cancel_revert
        notify-send -a caffeine "caffeine ON" "indefinitely"
    else
        revert_in "$dur"
        notify-send -a caffeine "caffeine ON" "auto-revert in $dur"
    fi
}

off_now() {
    cancel_revert
    systemctl --user start "$IDLE_UNIT" 2>/dev/null || true
    notify-send -a caffeine "caffeine off" "auto-lock and sleep re-enabled"
}

emit_status() {
    if is_caffeinated; then
        local label tip="caffeine ON"
        label=$(remaining_label)
        [[ -n "$label" ]] && tip="$tip — $label"
        printf '{"text":"%s","class":"on","tooltip":"%s"}\n' "$ICON" "$tip"
    else
        printf '{"text":"%s","class":"off","tooltip":"caffeine off (idle daemon active)"}\n' "$ICON"
    fi
}

case "${1:-status}" in
    status|"") emit_status ;;
    on)        on_for "${2:-30min}" ;;
    off)       off_now ;;
    toggle)    if is_caffeinated; then off_now; else on_for "${2:-30min}"; fi ;;
    menu)
        choice=$(printf "30 minutes\n2 hours\n5 hours\nforever\n──────────\nturn off\n" \
            | wofi --dmenu --width 240 --height 280 --location center --prompt "caffeine" --insensitive)
        case "$choice" in
            "30 minutes") on_for 30min ;;
            "2 hours")    on_for 2h ;;
            "5 hours")    on_for 5h ;;
            "forever")    on_for forever ;;
            "turn off")   off_now ;;
            *) ;;  # cancelled
        esac
        ;;
    *)
        echo "usage: $0 {status|on <dur>|off|toggle [dur]|menu}" >&2
        exit 2
        ;;
esac
