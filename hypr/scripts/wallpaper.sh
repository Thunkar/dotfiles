#!/usr/bin/env bash
# Apply the wallpaper to every connected monitor via hyprpaper IPC.
#
# Why not just rely on hyprpaper.conf's `wallpaper =` lines? With
# `ipc = on`, those static directives race against async preload at
# startup and frequently drop with "Monitor X has no target". Driving
# it over IPC once hyprpaper is up is reliable and needs no per-machine
# monitor names baked into config.
set -euo pipefail

WP="$HOME/.config/hypr/wallpapers/default.png"
[[ -f "$WP" ]] || exit 0

# Wait for hyprpaper to be running.
for _ in $(seq 1 20); do
    pgrep -x hyprpaper >/dev/null 2>&1 && break
    sleep 0.2
done

# Preload (best-effort; some hyprpaper builds reject the IPC verb but
# still have the config-preloaded image available).
hyprctl hyprpaper preload "$WP" >/dev/null 2>&1 || true

# Set on every monitor hyprland reports.
for mon in $(hyprctl -j monitors 2>/dev/null | python3 -c \
        'import json,sys; print("\n".join(m["name"] for m in json.load(sys.stdin)))' 2>/dev/null); do
    hyprctl hyprpaper wallpaper "$mon,$WP" >/dev/null 2>&1 || true
done
