[Appearance]
custom_palette=true
icon_theme=Papirus-Dark
standard_dialogs=default
# Fusion: Qt's built-in flat style. Reads the custom_palette below
# literally, no SVG, no Inactive-group dimming. Sufficient for CopyQ,
# pavucontrol, blueman, and anything else Qt-but-not-KDE-Frameworks-6.
style=Fusion
color_scheme_path=@HOME@/.config/qt6ct/colors/palette.conf

# NO [Fonts] section — deliberately. qt6ct stores fonts as a serialized
# QFont @Variant blob whose binary layout is tied to Qt's QDataStream
# version. A blob written for an older Qt deserialises to a broken QFont
# under Qt 6.11+, which makes EVERY Qt6 widget render with NO TEXT — blank
# dialogs, and crucially a blank xdg-desktop-portal screen-share picker
# (the symptom looks like a broken app; the root cause is this blob).
# Omitting the section lets Qt resolve fonts through fontconfig
# (sans-serif -> Noto Sans, monospace -> system mono), which is the intent
# anyway. To pin a specific Qt font, set it via the qt6ct GUI so it writes
# a blob matching the installed Qt — never hand-author the @Variant.

[Interface]
activate_item_on_single_click=1
buttonbox_layout=0
cursor_flash_time=1000
dialog_buttons_have_icons=1
double_click_interval=400
gui_effects=@Invalid()
keyboard_scheme=2
menus_have_icons=true
show_shortcuts_in_context_menus=true
stylesheets=@Invalid()
toolbutton_style=4
underline_shortcut=1
wheel_scroll_lines=3

[Troubleshooting]
# Keep OFF. AA_ForceRasterWidgets on Qt 6.11 + Wayland makes widgets'
# SHM backing buffer fail to allocate ("QWaylandShmBuffer: Invalid
# argument"), flooding logs; it doesn't help anything here.
force_raster_widgets=0
ignored_applications=@Invalid()
