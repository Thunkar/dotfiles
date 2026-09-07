-- Persistent workspaces split across monitors: odd → primary, even →
-- secondary (names come from conf/monitors.lua). Workspace 1 is the
-- default on the primary output.
local mon       = require("conf.monitors")
local secondary = mon.secondary or mon.primary

for i = 1, 10 do
    hl.workspace_rule({
        workspace  = tostring(i),
        monitor    = (i % 2 == 1) and mon.primary or secondary,
        persistent = true,
        default    = (i == 1),
    })
end
