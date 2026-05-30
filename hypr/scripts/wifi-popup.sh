#!/usr/bin/env bash
# Wofi-driven SSID picker for NetworkManager — replaces nmtui.
# Connects to a known profile or prompts for a password on first join.
# Right-click on the network pill in waybar still opens
# nm-connection-editor for advanced settings (VPN, IPv6, DNS, …).

set -euo pipefail

WOFI_ARGS=(--dmenu --width 460 --height 380 --location center --prompt wifi)

current_wifi_state() {
    nmcli -t -f WIFI g | grep -q '^enabled' && echo on || echo off
}

scan() {
    nmcli --terse --fields IN-USE,SIGNAL,SSID,SECURITY device wifi list --rescan auto 2>/dev/null \
        | awk -F: '
            $3 != "" && !seen[$3]++ {
                mark = ($1 == "*" ? "● " : "  ")
                sec  = ($4 == "" ? "open" : $4)
                printf "%s%-30s  %3s%%  %s\n", mark, $3, $2, sec
            }' \
        | sort -k3 -r
}

if [[ "$(current_wifi_state)" == "off" ]]; then
    choice=$(printf "  enable wifi\n  exit\n" | wofi "${WOFI_ARGS[@]}" || true)
    [[ "$choice" == *enable* ]] && nmcli radio wifi on
    exit 0
fi

readarray -t networks < <(scan)
if [[ ${#networks[@]} -eq 0 ]]; then
    notify-send -a wifi "no networks visible (scanning…)"
    exit 0
fi

header=$(printf "  disable wifi\n  open connection editor\n")
choice=$(printf "%s\n%s\n" "$header" "$(printf '%s\n' "${networks[@]}")" | wofi "${WOFI_ARGS[@]}" || true)
[[ -z "$choice" ]] && exit 0

case "$choice" in
    *disable\ wifi)
        nmcli radio wifi off
        exit 0
        ;;
    *connection\ editor)
        exec nm-connection-editor
        ;;
esac

# Strip leading mark + trailing "  NN%  SEC" → bare SSID.
ssid=$(printf '%s' "$choice" | sed -E 's/^[●[:space:]]+//; s/[[:space:]]+[0-9]+%[[:space:]]+[^[:space:]]+$//')

if nmcli -t -f NAME connection show --active | grep -qFx "$ssid"; then
    nmcli connection down "$ssid"
elif nmcli -t -f NAME connection show | grep -qFx "$ssid"; then
    nmcli connection up "$ssid"
else
    pw=$(printf '' | wofi "${WOFI_ARGS[@]}" --password --prompt "password for $ssid" --height 80 || true)
    [[ -z "$pw" ]] && exit 0
    nmcli device wifi connect "$ssid" password "$pw"
fi
