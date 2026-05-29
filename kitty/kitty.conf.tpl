# Kitty — Catppuccin Mocha, transparent, zsh.

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

# ── Catppuccin Mocha palette ───────────────────────────────────────
foreground              #@TEXT@
background              #@BASE@
selection_foreground    #@BASE@
selection_background    #@ROSEWATER@

cursor                  #@ROSEWATER@
cursor_text_color       #@BASE@
url_color               #@ROSEWATER@

active_border_color     #@MAUVE@
inactive_border_color   #@OVERLAY0@
bell_border_color       #@YELLOW@

active_tab_foreground   #@CRUST@
active_tab_background   #@MAUVE@
inactive_tab_foreground #@TEXT@
inactive_tab_background #@MANTLE@
tab_bar_background      #@CRUST@

# black
color0  #@SURFACE1@
color8  #@SURFACE2@
# red
color1  #@RED@
color9  #@RED@
# green
color2  #@GREEN@
color10 #@GREEN@
# yellow
color3  #@YELLOW@
color11 #@YELLOW@
# blue
color4  #@BLUE@
color12 #@BLUE@
# magenta
color5  #@PINK@
color13 #@PINK@
# cyan
color6  #@TEAL@
color14 #@TEAL@
# white
color7  #@SUBTEXT1@
color15 #@SUBTEXT0@
