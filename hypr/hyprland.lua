-- Hyprland configuration — entry point (Lua; Hyprland ≥ 0.55).
--
-- Modules under conf/ are loaded in the order below. Each is a plain Lua file
-- calling the `hl` API; `require` resolves relative to this directory, so
-- "conf.look" → conf/look.lua. Shared data flows through `require` too:
--   theme.colors   palette table rendered from theme/colors.env by apply.sh
--   conf.monitors  per-machine outputs + which one is primary/secondary
--
-- No environment variables are set here on purpose: the session is launched by
-- uwsm, so Hyprland and everything it spawns inherit ~/.config/environment.d/.
-- Use hl.env() only for a variable that must differ for Hyprland's children.
--
-- Validate without restarting:  Hyprland --verify-config -c ~/.config/hypr/hyprland.lua
-- Reload the live session:      hyprctl reload
-- API reference shipped with Hyprland: /usr/share/hypr/stubs/hl.meta.lua

require("conf.monitors")      -- per-machine: outputs, primary/secondary
require("conf.workspaces")    -- odd → primary, even → secondary
require("conf.look")          -- borders, gaps, blur, animations, layouts, misc
require("conf.input")         -- keyboard, mouse, gestures
require("conf.windowrules")
require("conf.keybinds")
require("conf.autostart")

-- Optional per-machine overrides: hypr/local.lua (gitignored, kept by apply.sh).
-- Loaded last so it can override anything above. A missing file is fine; a
-- broken one is reported like any other config error.
local ok, err = pcall(require, "local")
if not ok and not tostring(err):find("module 'local' not found", 1, true) then
    error(err, 0)
end
