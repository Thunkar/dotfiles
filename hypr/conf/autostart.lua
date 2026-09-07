-- Startup behaviour.
--
-- Session daemons (waybar, mako, hypridle, swaybg, cliphist, xsettingsd, the
-- polkit agent) are NOT started here. uwsm runs Hyprland as a systemd unit
-- and activates graphical-session.target once the compositor is up; the
-- daemons are user units wanted by that target (systemd/user/ + apply.sh's
-- apply_systemd), so they get restarts, logs and clean shutdown for free.
-- The same goes for env vars (environment.d/) and D-Bus activation
-- (portals) — uwsm exports the Wayland session to systemd/D-Bus itself.

hl.on("hyprland.start", function()
    -- Land on the primary monitor's workspace 1. With two outputs Hyprland
    -- otherwise comes up focused on the secondary's workspace; a short delay
    -- lets the outputs settle first.
    hl.timer(function()
        hl.dispatch(hl.dsp.focus({ workspace = 1 }))
    end, { timeout = 1000, type = "oneshot" })
end)
