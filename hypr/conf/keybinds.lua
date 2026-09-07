-- Keybindings.
--
-- bind(keys, dispatcher, cheat, opts): `cheat` is "category | description".
-- It is stored as the bind's description, which `hyprctl binds -j` exposes,
-- and scripts/cheatsheet.sh (SUPER+F11) renders it grouped by category.
local M           = "SUPER"
local terminal    = "kitty"
local fileManager = "nautilus"
local menu        = "wofi --show drun"
local scripts     = "~/.config/hypr/scripts"

local function bind(keys, dispatcher, cheat, opts)
    opts = opts or {}
    if cheat then opts.description = cheat end
    return hl.bind(keys, dispatcher, opts)
end

-- ── Apps ────────────────────────────────────────────────────────────
bind(M .. " + Q",         hl.dsp.exec_cmd(terminal),    "apps | open terminal")
bind(M .. " + E",         hl.dsp.exec_cmd(fileManager), "apps | file manager")
bind(M .. " + SPACE",     hl.dsp.exec_cmd(menu),        "apps | app launcher (wofi)")
bind(M .. " + V",         hl.dsp.exec_cmd(scripts .. "/cliphist-pick.sh"),        "apps | clipboard history (wofi picker)")
bind(M .. " + SHIFT + V", hl.dsp.exec_cmd(scripts .. "/cliphist-pick.sh delete"), "apps | clipboard: delete entry")

-- Quake-style dropdown terminal, no external helper: the kitty_dropdown window
-- rule parks it on the special workspace "dropdown"; F11 toggles that
-- workspace, or launches the terminal the first time.
bind("F11", function()
    if #hl.get_windows({ class = "kitty_dropdown" }) > 0 then
        hl.dispatch(hl.dsp.workspace.toggle_special("dropdown"))
    else
        hl.exec_cmd(terminal .. " --class kitty_dropdown")
    end
end, "apps | dropdown terminal")

-- ── Window management ───────────────────────────────────────────────
bind(M .. " + C", hl.dsp.window.close(),                             "window | close focused window")
bind(M .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }), "window | fullscreen")
bind(M .. " + T", hl.dsp.window.float({ action = "toggle" }),        "window | toggle float")
bind(M .. " + P", hl.dsp.window.pseudo(),                            "window | pseudo (dwindle)")
bind(M .. " + J", hl.dsp.layout("togglesplit"),                      "window | toggle split direction")

for _, d in ipairs({ "left", "right", "up", "down" }) do
    bind(M .. " + " .. d, hl.dsp.focus({ direction = d }), "focus | focus " .. d)
end
for _, d in ipairs({ "left", "right", "up", "down" }) do
    bind(M .. " + SHIFT + " .. d, hl.dsp.window.move({ direction = d }), "focus | move window " .. d)
end

-- Mouse drag move/resize.
bind(M .. " + mouse:272", hl.dsp.window.drag(),   "window | drag to move (SUPER+LMB)",   { mouse = true })
bind(M .. " + mouse:273", hl.dsp.window.resize(), "window | drag to resize (SUPER+RMB)", { mouse = true })

-- Resize submap: arrows resize while held, Return/Escape leave the mode.
bind(M .. " + R", hl.dsp.submap("resize"), "window | enter resize mode (Return/Esc to exit)")
hl.define_submap("resize", function()
    local step = 30
    hl.bind("right",  hl.dsp.window.resize({ x =  step, y = 0,     relative = true }), { repeating = true })
    hl.bind("left",   hl.dsp.window.resize({ x = -step, y = 0,     relative = true }), { repeating = true })
    hl.bind("up",     hl.dsp.window.resize({ x = 0,     y = -step, relative = true }), { repeating = true })
    hl.bind("down",   hl.dsp.window.resize({ x = 0,     y =  step, relative = true }), { repeating = true })
    hl.bind("Return", hl.dsp.submap("reset"))
    hl.bind("escape", hl.dsp.submap("reset"))
end)

-- ── Workspaces ──────────────────────────────────────────────────────
for i = 1, 10 do
    local key = tostring(i % 10)   -- 10 → key 0
    bind(M .. " + " .. key,         hl.dsp.focus({ workspace = i }),
         i == 1 and "workspace | switch to ws 1-9,0 (odd: primary, even: secondary)" or nil)
    bind(M .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }),
         i == 1 and "workspace | move window → ws N" or nil)
end

bind(M .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }),      "workspace | scroll to next")
bind(M .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }),      "workspace | scroll to previous")
bind(M .. " + Tab",        hl.dsp.focus({ workspace = "previous" }), "workspace | last workspace")

-- Scratchpad.
bind(M .. " + S",         hl.dsp.workspace.toggle_special("magic"),            "workspace | toggle scratchpad")
bind(M .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }), "workspace | move window → scratchpad")

-- ── System ──────────────────────────────────────────────────────────
bind(M .. " + F11",       hl.dsp.exec_cmd(scripts .. "/cheatsheet.sh"), "system | cheatsheet (this popup)")
bind(M .. " + N",         hl.dsp.exec_cmd("makoctl dismiss"),           "system | dismiss top notification")
bind(M .. " + SHIFT + N", hl.dsp.exec_cmd("makoctl dismiss --all"),     "system | dismiss ALL notifications")
bind(M .. " + SHIFT + L", hl.dsp.exec_cmd("loginctl lock-session"),     "system | lock screen now")
bind(M .. " + M",         hl.dsp.exec_cmd("wlogout"),                   "system | power menu (lock/logout/suspend/reboot/off)")
bind("ALT + SHIFT + 4",   hl.dsp.exec_cmd(scripts .. "/screenshot.sh region"),          "system | screenshot region → clipboard + file")
bind("ALT + SHIFT + 5",   hl.dsp.exec_cmd(scripts .. "/screenshot.sh region annotate"), "system | screenshot region → annotate (satty) → clipboard")
bind("Print",             hl.dsp.exec_cmd(scripts .. "/screenshot.sh screen"),          "system | screenshot full screen → clipboard + file")
bind(M .. " + Print",     hl.dsp.exec_cmd(scripts .. "/screenshot.sh window"),          "system | screenshot active window → clipboard + file")

-- ── Multimedia keys (work while locked; volume/brightness repeat when held) ──
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
