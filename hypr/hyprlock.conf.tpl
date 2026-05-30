# Hyprlock — lock screen.

general {
    hide_cursor = true
    # NOTE: `grace` and `disable_loading_bar` were removed from the
    # [general] schema in hyprlock 0.9.x — leaving them in makes
    # hyprlock fail to lock. Do not re-add them here.
}

background {
    monitor     =
    # Blur the actual wallpaper (blur_* do nothing without a path).
    # apply.sh substitutes @HOME@ → absolute path (hyprlock won't expand ~).
    path        = @HOME@/.config/hypr/wallpapers/default.png
    color       = rgba(@BASE_R@, @BASE_G@, @BASE_B@, 1.0)
    blur_passes = 3
    blur_size   = 8
    noise       = 0.012
    contrast    = 0.9
    brightness  = 0.85
    vibrancy    = 0.18
}

# Big clock.
label {
    monitor      =
    text         = cmd[update:1000] echo "$(date +%H:%M)"
    color        = rgba(@TEXT_R@, @TEXT_G@, @TEXT_B@, 1.0)
    font_size    = 96
    font_family  = JetBrainsMono Nerd Font Bold
    position     = 0, 80
    halign       = center
    valign       = center
}

# Date.
label {
    monitor      =
    text         = cmd[update:60000] echo "$(date '+%a %d %b %Y')"
    color        = rgba(@SUBTEXT1_R@, @SUBTEXT1_G@, @SUBTEXT1_B@, 1.0)
    font_size    = 22
    font_family  = JetBrainsMono Nerd Font
    position     = 0, -10
    halign       = center
    valign       = center
}

# Username pill.
label {
    monitor      =
    text         = $USER
    color        = rgba(@LAVENDER_R@, @LAVENDER_G@, @LAVENDER_B@, 1.0)
    font_size    = 14
    font_family  = JetBrainsMono Nerd Font
    position     = 0, -90
    halign       = center
    valign       = center
}

# Password input.
input-field {
    monitor          =
    size             = 320, 50
    outline_thickness = 2
    rounding         = 16
    inner_color      = rgba(@SURFACE0_R@, @SURFACE0_G@, @SURFACE0_B@, 0.78)
    outer_color      = rgba(@MAUVE_R@, @MAUVE_G@, @MAUVE_B@, 0.85)
    check_color      = rgba(@GREEN_R@, @GREEN_G@, @GREEN_B@, 1.0)
    fail_color       = rgba(@RED_R@, @RED_G@, @RED_B@, 1.0)
    font_color       = rgba(@TEXT_R@, @TEXT_G@, @TEXT_B@, 1.0)
    placeholder_text = <span foreground="##@SUBTEXT0@">enter password</span>
    fail_text        = <span>$FAIL ($ATTEMPTS)</span>
    fade_on_empty    = false
    capslock_color   = rgba(@YELLOW_R@, @YELLOW_G@, @YELLOW_B@, 1.0)
    position         = 0, -160
    halign           = center
    valign           = center
}
