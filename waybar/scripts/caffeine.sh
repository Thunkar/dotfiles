#!/usr/bin/env bash
# Caffeine for Hyprland: inhibits hypridle for a chosen duration.
#
#   caffeine.sh                  emit waybar JSON state
#   caffeine.sh status           (alias of the no-arg form)
#   caffeine.sh on <duration>    kill hypridle for <duration>, auto-revert
#   caffeine.sh off              re-enable hypridle now
#   caffeine.sh toggle [dur]     off → on:<dur>, on → off  (dur defaults 30m)
#   caffeine.sh menu             wofi picker over preset durations
#
# <duration> is anything systemd accepts (30min, 2h, 5h) OR the
# literal word "forever". The auto-revert is a transient systemd-user
# timer (`caffeine-revert.timer`); cancelling caffeine stops the timer.

set -euo pipefail

ICON=$'\xef\x83\xb4'    # nf-fa-coffee
SERVICE="caffeine-revert"

is_caffeinated() { ! pgrep -x hypridle >/dev/null 2>&1; }

revert_in() {
    # Schedule a one-shot user-unit that re-spawns hypridle after <duration>.
    local dur="$1"
    systemctl --user stop "$SERVICE.timer" "$SERVICE.service" 2>/dev/null || true
    systemd-run --user --quiet \
        --unit="$SERVICE" \
        --on-active="$dur" \
        --description="caffeine auto-revert" \
        /bin/sh -c 'setsid -f hypridle >/dev/null 2>&1'
}

cancel_revert() {
    systemctl --user stop "$SERVICE.timer" "$SERVICE.service" 2>/dev/null || true
}

remaining_label() {
    # Show "Xh Ym left" if our revert timer is scheduled. systemctl
    # list-timers prints lines like:
    #   Fri 2026-05-29 16:15:09 CEST 29min - - caffeine-revert.timer …
    # The first four tokens form a date+time+tz that `date -d` parses,
    # giving us an absolute trigger time to subtract `now` from.
    local line ts now diff h m
    line=$(systemctl --user list-timers "$SERVICE.timer" --no-legend 2>/dev/null | head -n1)
    if [[ -z "$line" ]]; then
        is_caffeinated && echo "forever" || echo ""
        return
    fi
    ts=$(awk '{print $1, $2, $3, $4}' <<<"$line")
    ts=$(date -d "$ts" +%s 2>/dev/null || echo 0)
    [[ "$ts" -eq 0 ]] && { echo "forever"; return; }
    now=$(date +%s)
    diff=$(( ts - now ))
    (( diff < 0 )) && diff=0
    h=$(( diff / 3600 ))
    m=$(( (diff % 3600) / 60 ))
    if (( h > 0 )); then echo "${h}h ${m}m left"
    else                echo "${m}m left"
    fi
}

on_for() {
    local dur="$1"
    pkill -x hypridle 2>/dev/null || true
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
    if ! pgrep -x hypridle >/dev/null 2>&1; then
        setsid -f hypridle >/dev/null 2>&1 || hypridle >/dev/null 2>&1 &
    fi
    notify-send -a caffeine "caffeine off" "auto-lock and sleep re-enabled"
}

emit_status() {
    if is_caffeinated; then
        local label; label=$(remaining_label)
        local tip="caffeine ON"
        [[ -n "$label" ]] && tip="$tip — $label"
        printf '{"text":"%s","class":"on","tooltip":"%s"}\n' "$ICON" "$tip"
    else
        printf '{"text":"%s","class":"off","tooltip":"caffeine off (idle daemon active)"}\n' "$ICON"
    fi
}

case "${1:-status}" in
    status|"")
        emit_status
        ;;
    on)
        on_for "${2:-30min}"
        ;;
    off)
        off_now
        ;;
    toggle)
        if is_caffeinated; then off_now
        else                    on_for "${2:-30min}"
        fi
        ;;
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
