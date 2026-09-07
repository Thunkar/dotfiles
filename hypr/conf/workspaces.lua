-- Persistent workspaces split across monitors: odd → primary, even →
-- secondary (from conf/monitors.lua / machine.lua). Workspace 1 is the
-- default on the primary output. With no monitors declared (single-output
-- box, no machine.lua) the rules carry no monitor and Hyprland places them.
local mon       = require("conf.monitors")
local primary   = (mon.primary   ~= nil and mon.primary   ~= "") and mon.primary   or nil
local secondary = (mon.secondary ~= nil and mon.secondary ~= "") and mon.secondary or primary

for i = 1, 10 do
    hl.workspace_rule({
        workspace  = tostring(i),
        monitor    = (i % 2 == 1) and primary or secondary,
        persistent = true,
        default    = (i == 1),
    })
end
