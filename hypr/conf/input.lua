-- Keyboard, pointer, gestures.
hl.config({
    input = {
        kb_layout    = "es",
        kb_variant   = "",
        kb_model     = "",
        kb_options   = "",
        kb_rules     = "",
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad = { natural_scroll = false },
    },
})

-- Three-finger horizontal swipe switches workspace.
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Per-device tweaks go here, e.g.
-- hl.device({ name = "my-mouse-name", sensitivity = -0.5 })   -- names: hyprctl devices
