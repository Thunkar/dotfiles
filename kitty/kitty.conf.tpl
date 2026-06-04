# Kitty — transparent, zsh.

# ── Shell ──────────────────────────────────────────────────────────
# Hard-coded so kitty does not fall back to fish (or whatever the
# parent process's $SHELL was when the Hyprland session started).
shell /usr/bin/zsh
shell_integration enabled

# ── Font ───────────────────────────────────────────────────────────
font_family      JetBrainsMono Nerd Font
bold_font        JetBrainsMono Nerd Font Bold
italic_font      JetBrainsMono Nerd Font Italic
bold_italic_font JetBrainsMono Nerd Font Bold Italic
font_size        12.0

# ── Window ─────────────────────────────────────────────────────────
background_opacity      0.80
dynamic_background_opacity yes
background_blur         32
window_padding_width    10
hide_window_decorations yes
confirm_os_window_close 0
enable_audio_bell       no
cursor_blink_interval   0.5
cursor_shape            beam
copy_on_select          yes
url_style               curly
strip_trailing_spaces   smart

# ── Tabs (minimal, slanted) ────────────────────────────────────────
tab_bar_edge        top
tab_bar_style       powerline
tab_powerline_style slanted
tab_title_template  "{index}: {title[:24]}"

# ── Color palette ───────────────────────────────────────
foreground              #@FG@
background              #@BG@
selection_foreground    #@BG@
selection_background    #@ACCENT@

cursor                  #@ACCENT@
cursor_text_color       #@BG@
url_color               #@ACCENT@

active_border_color     #@ACCENT@
inactive_border_color   #@MUTED@
bell_border_color       #@WARNING@

active_tab_foreground   #@BG_DEEP@
active_tab_background   #@ACCENT@
inactive_tab_foreground #@FG@
inactive_tab_background #@BG_ALT@
tab_bar_background      #@BG_DEEP@

# black
color0  #@SURFACE1@
color8  #@SURFACE2@
# red
color1  #@ERROR@
color9  #@ERROR@
# green
color2  #@SUCCESS@
color10 #@SUCCESS@
# yellow
color3  #@WARNING@
color11 #@WARNING@
# blue
color4  #@ACCENT_ALT@
color12 #@ACCENT_ALT@
# magenta
color5  #@ACCENT_ALT@
color13 #@ACCENT_ALT@
# cyan
color6  #@ACCENT_ALT@
color14 #@ACCENT_ALT@
# white
color7  #@FG_DIM@
color15 #@FG_FAINT@
