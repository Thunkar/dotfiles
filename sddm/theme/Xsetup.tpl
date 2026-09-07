#!/bin/sh
# SDDM X11 setup script — rendered from sddm/theme/Xsetup.tpl by apply.sh
# and run as root right before the greeter starts (DisplayCommand in
# /etc/sddm.conf.d/10-theme.conf).
#
# Marks the Hyprland primary output (conf/monitors.lua) as the X11 primary
# screen. SDDM draws the theme on every screen but activates (gives keyboard
# focus to) the primary one, and Main.qml only shows the login card there —
# the other screens just show the blurred wallpaper.
#
# Xorg names outputs differently from the kernel/Hyprland: the amdgpu DDX
# uses DisplayPort-2 / HDMI-A-0 for DP-3 / HDMI-A-1, modesetting uses HDMI-1.
# So match on connector type first, exact name second, and give up (keeping
# X's default) if it is ambiguous.
want="@PRIMARY_OUTPUT@"
[ -n "$want" ] || exit 0
command -v xrandr >/dev/null 2>&1 || exit 0

connected=$(xrandr -q 2>/dev/null | awk '/ connected/ { print $1 }')
[ -n "$connected" ] || exit 0

type=${want%-*}                       # DP-3 → DP, HDMI-A-1 → HDMI-A, eDP-1 → eDP
case "$type" in
    DP)     pat='^(DP|DisplayPort)-' ;;
    HDMI-A) pat='^HDMI(-A)?-' ;;
    *)      pat="^$type-" ;;
esac

matches=$(printf '%s\n' "$connected" | grep -E "$pat" || true)
if [ "$(printf '%s\n' "$matches" | grep -c .)" -eq 1 ]; then
    target=$matches
elif printf '%s\n' "$connected" | grep -qx "$want"; then
    target=$want
else
    exit 0
fi

xrandr --output "$target" --primary
