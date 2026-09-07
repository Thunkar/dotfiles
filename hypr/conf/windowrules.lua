-- Window rules. `match` selects windows (regex on class/title, booleans for
-- state); the remaining fields are the effects applied to them.

-- Hyprland tiles: ignore maximize requests from every app.
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- Fix dragging glitches in XWayland popups with no class/title.
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

-- hyprland-run launcher: floating bar pinned bottom-left.
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },
    float = true,
    move  = "20 monitor_h-120",
})

-- Dropdown terminal (F11 in conf/keybinds.lua): Quake-style panel parked on
-- the special workspace "dropdown".
hl.window_rule({
    name  = "kitty-dropdown",
    match = { class = "kitty_dropdown" },
    float     = true,
    size      = "80% 40%",
    move      = "10% 5%",
    animation = "slide",
    workspace = "special:dropdown",
    opacity   = 0.85,
})

-- Cheatsheet popup: centred, floating, pinned.
hl.window_rule({
    name  = "hypr-cheatsheet",
    match = { class = "hypr-cheatsheet" },
    float     = true,
    size      = "88% 88%",
    center    = true,
    pin       = true,
    opacity   = 0.95,
    rounding  = 14,
    animation = "popin",
})

-- Audio mixer (pulsemixer in kitty), spawned from the waybar audio pill.
hl.window_rule({
    name  = "hypr-audio-popup",
    match = { class = "hypr-audio-popup" },
    float     = true,
    size      = "540 360",
    move      = "100%-560 60",
    pin       = true,
    opacity   = 0.92,
    rounding  = 14,
    animation = "slide",
})

-- Bluetooth manager (bluetuith in kitty), spawned from the waybar bt pill.
hl.window_rule({
    name  = "hypr-bt-popup",
    match = { class = "hypr-bt-popup" },
    float     = true,
    size      = "620 420",
    move      = "100%-640 60",
    pin       = true,
    opacity   = 0.92,
    rounding  = 14,
    animation = "slide",
})

-- Common dialogs / pickers float.
hl.window_rule({
    name  = "float-dialogs",
    match = { class = "^(pavucontrol|nm-applet|nwg-look|file-roller|blueman-manager)$" },
    float = true,
})

-- Polkit prompt + GTK portal dialogs: floating and centred.
hl.window_rule({
    name  = "float-polkit",
    match = { class = "^(hyprpolkitagent|xdg-desktop-portal-gtk)$" },
    float  = true,
    center = true,
})

-- PrusaSlicer: prusaslicer:// links (Printables) switch to its workspace.
-- Redundant with misc.focus_on_activate = true; kept as explicit intent.
hl.window_rule({
    name  = "prusaslicer-focus",
    match = { class = "^(com\\.prusa3d\\.PrusaSlicer|PrusaSlicer)$" },
    focus_on_activate = true,
})

-- Telegram fires xdg-activation on EVERY message. Drop the focus part so it
-- stops yanking you across workspaces (trade-off: clicking a Telegram
-- notification won't raise it either). Add other offenders to the regex.
hl.window_rule({
    name  = "telegram-no-focus-steal",
    match = { class = "^(org\\.telegram\\.desktop)$" },
    suppress_event = "activatefocus",
})

-- Picture-in-picture: floating, pinned across workspaces, bottom-right.
hl.window_rule({
    name  = "pip",
    match = { title = "^(Picture-in-Picture)$" },
    float = true,
    pin   = true,
    size  = "480 270",
    move  = "100%-500 100%-310",
})
