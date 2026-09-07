-- =====================================================================
-- MONITORS — the one file you edit per machine. Git keeps YOUR copy on
-- merges (merge=ours in .gitattributes).
-- =====================================================================
-- `hyprctl monitors` lists output names (DP-3, HDMI-A-1, eDP-1, …) and modes.
--
--   primary   → odd workspaces (1,3,5,7,9) and the SDDM login prompt
--   secondary → even workspaces (2,4,6,8,10)
--
-- Single monitor: set both to the same name, or drop `secondary`.
-- apply.sh reads the `primary = "…"` line to tell SDDM which output shows
-- the password prompt — keep it on one line, in double quotes.
-- =====================================================================
local M = {
    primary   = "DP-3",
    secondary = "HDMI-A-1",
}

-- Catch-all: any output not listed below comes up at its preferred mode.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- This machine: dual 27" 1440p — DP-3 (240 Hz) on the right, HDMI-A-1 (60 Hz) left.
hl.monitor({ output = "DP-3",     mode = "2560x1440@240", position = "2560x0", scale = 1 })
hl.monitor({ output = "HDMI-A-1", mode = "2560x1440@60",  position = "0x0",    scale = 1 })

return M
