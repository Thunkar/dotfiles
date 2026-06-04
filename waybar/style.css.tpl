/* minimal floating-pill bar.
 * The bar window itself is invisible; each module group gets its own
 * rounded "pill" with a soft accent tint and 1px lavender border. */

* {
    font-family: "JetBrainsMono Nerd Font", "Symbols Nerd Font", "Noto Sans", monospace;
    font-size: 12px;
    border: none;
    border-radius: 0;
    min-height: 0;
}

window#waybar {
    background-color: transparent;
    color: #@TEXT@;
}

/* The three module-row containers stay transparent — only the pills show. */
.modules-left,
.modules-center,
.modules-right {
    background: transparent;
    padding: 0;
}

/* Default pill style applied to every module. Each one floats on its own. */
#workspaces,
#submap,
#window,
#clock,
#network,
#bluetooth,
#pulseaudio,
#tray,
#custom-mako,
#custom-caffeine,
#custom-claude-usage,
#custom-power {
    background-color: rgba(@BASE_R@, @BASE_G@, @BASE_B@, 0.78);
    border: 1px solid rgba(@MAUVE_R@, @MAUVE_G@, @MAUVE_B@, 0.16);
    border-radius: 999px;
    padding: 0 12px;
    margin: 3px 3px;
    color: #@TEXT@;
    transition: background-color 150ms ease, color 150ms ease;
}

/* ── Workspaces ────────────────────────────────────────────────── */
#workspaces {
    padding: 0 4px;
}

#workspaces button {
    padding: 0 8px;
    margin: 2px 1px;
    color: #@OVERLAY0@;
    background: transparent;
    border-radius: 999px;
    transition: all 150ms ease;
}

#workspaces button:hover {
    color: #@TEXT@;
    background: rgba(@MAUVE_R@, @MAUVE_G@, @MAUVE_B@, 0.18);
}

#workspaces button.active {
    color: #@CRUST@;
    background-color: #@MAUVE@;
    box-shadow: 0 0 6px rgba(@MAUVE_R@, @MAUVE_G@, @MAUVE_B@, 0.55);
}

#workspaces button.urgent {
    color: #@CRUST@;
    background-color: #@RED@;
}

/* ── wlr/taskbar (open apps in centre, one icon per window) ────── */
/* Wlr taskbar uses GTK image widgets so it can render real icons
 * from the system icon theme (Papirus-Dark, set via gsettings).
 * `all-outputs=false` in the module config means each monitor's bar
 * only shows the windows on workspaces assigned to that monitor —
 * matching the odd/even-monitor split in hypr/conf.d/10-monitors.conf. */
#taskbar {
    background-color: rgba(@BASE_R@, @BASE_G@, @BASE_B@, 0.78);
    border: 1px solid rgba(@MAUVE_R@, @MAUVE_G@, @MAUVE_B@, 0.16);
    border-radius: 999px;
    padding: 0 6px;
    margin: 3px 3px;
}
#taskbar button {
    padding: 0 6px;
    margin: 2px 1px;
    background: transparent;
    border: 0;
    border-radius: 8px;
    transition: background 150ms ease;
}
#taskbar button:hover {
    background: rgba(@MAUVE_R@, @MAUVE_G@, @MAUVE_B@, 0.20);
}
#taskbar button.active {
    background: rgba(@MAUVE_R@, @MAUVE_G@, @MAUVE_B@, 0.30);
}

/* ── Submap indicator (RESIZE / LAYOUTS) ───────────────────────── */
#submap {
    color: #@YELLOW@;
    background-color: rgba(@YELLOW_R@, @YELLOW_G@, @YELLOW_B@, 0.14);
    border-color: rgba(@YELLOW_R@, @YELLOW_G@, @YELLOW_B@, 0.30);
}

/* ── Focused window title ──────────────────────────────────────── */
#window {
    color: #@SUBTEXT1@;
    font-style: italic;
}

window#waybar.empty #window {
    background-color: transparent;
    border-color: transparent;
}

/* ── Right-cluster accent colors ───────────────────────────────── */
#clock {
    color: #@LAVENDER@;
}

#network {
    color: #@TEAL@;
}

#bluetooth {
    color: #@BLUE@;
}

#bluetooth.disabled,
#bluetooth.off {
    color: #@OVERLAY0@;
}

#pulseaudio {
    color: #@PINK@;
}

#pulseaudio.muted {
    color: #@OVERLAY0@;
}

#custom-mako.dnd {
    color: #@OVERLAY0@;
}

#custom-mako.on {
    color: #@GREEN@;
}

/* Active = solid accent fill with dark text, so the coffee glyph stays
 * legible regardless of how light/dark the accent token is. */
#custom-caffeine.on {
    color: #@CRUST@;
    background-color: #@YELLOW@;
    border-color: #@YELLOW@;
}

#custom-caffeine.off {
    color: #@OVERLAY0@;
}

#custom-claude-usage.low {
    color: #@GREEN@;
}

#custom-claude-usage.medium {
    color: #@YELLOW@;
}

#custom-claude-usage.high {
    color: #@RED@;
}

#custom-claude-usage.error {
    color: #@RED@;
}

#tray menu {
    background-color: rgba(@BASE_R@, @BASE_G@, @BASE_B@, 0.95);
    color: #@TEXT@;
    border-radius: 10px;
    padding: 6px;
}

/* Power keeps its red tint but matches every other pill's metrics
 * (font-size, padding) so the bar's vertical baseline stays clean. */
#custom-power {
    color: #@RED@;
    background-color: rgba(@RED_R@, @RED_G@, @RED_B@, 0.14);
    border-color: rgba(@RED_R@, @RED_G@, @RED_B@, 0.32);
}

#custom-power:hover {
    color: #@CRUST@;
    background-color: #@RED@;
}

/* Single-glyph pills (caffeine, mako, power). Force them to the
 * `Mono` variant of JetBrainsMono Nerd Font (suffix "Mono"). That
 * variant constrains every icon glyph to a single mono cell with the
 * visible mark properly centred — the default "JetBrainsMono Nerd
 * Font" is the propo variant which lets icon glyphs be wider and
 * off-centred. Symmetric padding around a properly-centred glyph
 * gives optical centering with no per-pill tweaks. */
#custom-caffeine,
#custom-mako,
#custom-power {
    font-family: "JetBrainsMono Nerd Font Mono", "Symbols Nerd Font", monospace;
    font-size: 16px;
}

/* FA's coffee glyph (U+F0F4) is drawn smaller than peers in JBM
 * Nerd Font Mono — bump caffeine specifically so it visually matches
 * the bell and the power icon. */
#custom-caffeine {
    font-size: 21px;
}

/* ── Tooltips ─────────────────────────────────────────────────── */
tooltip {
    background-color: rgba(@CRUST_R@, @CRUST_G@, @CRUST_B@, 0.95);
    border: 1px solid rgba(@MAUVE_R@, @MAUVE_G@, @MAUVE_B@, 0.4);
    border-radius: 10px;
    color: #@TEXT@;
}

tooltip label {
    padding: 4px;
}