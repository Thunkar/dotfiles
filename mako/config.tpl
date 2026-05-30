# Mako — notification daemon.
# Reload with: makoctl reload

font=JetBrainsMono Nerd Font 11
background-color=#@BASE@ee
text-color=#@TEXT@
border-color=#@MAUVE@
border-size=2
border-radius=12
progress-color=over #@SURFACE1@

default-timeout=5000
ignore-timeout=0
group-by=app-name

width=380
height=140
margin=10
padding=14,18
icon-path=/usr/share/icons/Papirus-Dark
max-icon-size=48

layer=overlay
anchor=top-right
output=

[urgency=low]
border-color=#@BLUE@
default-timeout=3000

[urgency=normal]
border-color=#@MAUVE@

[urgency=high]
border-color=#@RED@
text-color=#@RED@
default-timeout=0

# ── Messaging / chat apps ────────────────────────────────────────
# Bigger, stickier, distinct accent so chat pings don't get lost
# among system notifications. 15s timeout (vs 5s default) and a
# blue/green/peach border depending on the app, so you can tell at
# a glance which client pinged.

[app-name=Slack]
default-timeout=10000
border-color=#@GREEN@
text-color=#@GREEN@
width=440
height=180
padding=16,20

[app-name=Signal]
default-timeout=10000
border-color=#@BLUE@
text-color=#@BLUE@
width=440
height=180
padding=16,20

# Mako criteria parser splits on whitespace — values containing
# spaces (like "Telegram Desktop") must be quoted.
[app-name=telegram-desktop]
default-timeout=10000
border-color=#@SAPPHIRE@
text-color=#@SAPPHIRE@
width=440
height=180
padding=16,20

[app-name="Telegram Desktop"]
default-timeout=10000
border-color=#@SAPPHIRE@
text-color=#@SAPPHIRE@
width=440
height=180
padding=16,20

[app-name=discord]
default-timeout=10000
border-color=#@LAVENDER@
text-color=#@LAVENDER@
width=440
height=180
padding=16,20

[mode=do-not-disturb]
invisible=1
