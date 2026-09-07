-- Monitors. Generic defaults that work on any single-output machine; the
-- real per-machine layout lives in hypr/machine.lua, which is gitignored so
-- it never leaks into commits or upstream PRs (see README "Per-machine").
--
-- hypr/machine.lua declares outputs and returns which is primary/secondary:
--
--   hl.monitor({ output = "DP-3",     mode = "2560x1440@240", position = "2560x0", scale = 1 })
--   hl.monitor({ output = "HDMI-A-1", mode = "2560x1440@60",  position = "0x0",    scale = 1 })
--   return { primary = "DP-3", secondary = "HDMI-A-1" }
--
--   primary   → odd workspaces (1,3,5,7,9) and the SDDM login prompt
--   secondary → even workspaces (2,4,6,8,10); omit it on a single monitor
--
-- `hyprctl monitors` lists output names and modes. apply.sh reads the
-- `primary = "…"` value (machine.lua first, then this file) for SDDM.
local M = { primary = "", secondary = nil }

-- Catch-all: any output not declared elsewhere comes up at its preferred mode.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

local ok, machine = pcall(require, "machine")
if ok then
    if type(machine) == "table" then
        for k, v in pairs(machine) do M[k] = v end
    end
elseif not tostring(machine):find("module 'machine' not found", 1, true) then
    error(machine, 0)   -- a broken machine.lua is a config error, not "no file"
end

return M
