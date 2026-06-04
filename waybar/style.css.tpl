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
    color: #@FG@;
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
    background-color: rgba(@BG_R@, @BG_G@, @BG_B@, 0.78);
    border: 1px solid rgba(@ACCENT_R@, @ACCENT_G@, @ACCENT_B@, 0.16);
    border-radius: 999px;
    padding: 0 12px;
    margin: 3px 3px;
    color: #@FG@;
    transition: background-color 150ms ease, color 150ms ease;
}

/* ── Workspaces ────────────────────────────────────────────────── */
#workspaces {
    padding: 0 4px;
}

#workspaces button {
    padding: 0 8px;
    margin: 2px 1px;
    color: #@MUTED@;
    background: transparent;
    border-radius: 999px;
    transition: all 150ms ease;
}

#workspaces button:hover {
    color: #@FG@;
    background: rgba(@ACCENT_R@, @ACCENT_G@, @ACCENT_B@, 0.18);
}

#workspaces button.active {
    color: #@BG_DEEP@;
    background-color: #@ACCENT@;
    box-shadow: 0 0 6px rgba(@ACCENT_R@, @ACCENT_G@, @ACCENT_B@, 0.55);
}

#workspaces button.urgent {
    color: #@BG_DEEP@;
    background-color: #@ERROR@;
}

/* ── wlr/taskbar (open apps in centre, one icon per window) ────── */
/* Wlr taskbar uses GTK image widgets so it can render real icons
 * from the system icon theme (Papirus-Dark, set via gsettings).
 * `all-outputs=false` in the module config means each monitor's bar
 * only shows the windows on workspaces assigned to that monitor —
 * matching the odd/even-monitor split in hypr/conf.d/10-monitors.conf. */
#taskbar {
    background-color: rgba(@BG_R@, @BG_G@, @BG_B@, 0.78);
    border: 1px solid rgba(@ACCENT_R@, @ACCENT_G@, @ACCENT_B@, 0.16);
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
    background: rgba(@ACCENT_R@, @ACCENT_G@, @ACCENT_B@, 0.20);
}
#taskbar button.active {
    background: rgba(@ACCENT_R@, @ACCENT_G@, @ACCENT_B@, 0.30);
}

/* ── Submap indicator (RESIZE / LAYOUTS) ───────────────────────── */
#submap {
    color: #@WARNING@;
    background-color: rgba(@WARNING_R@, @WARNING_G@, @WARNING_B@, 0.14);
    border-color: rgba(@WARNING_R@, @WARNING_G@, @WARNING_B@, 0.30);
}

/* ── Focused window title ──────────────────────────────────────── */
#window {
    color: #@FG_DIM@;
    font-style: italic;
}

window#waybar.empty #window {
    background-color: transparent;
    border-color: transparent;
}

/* ── Right-cluster accent colors ───────────────────────────────── */
#clock {
    color: #@ACCENT_DIM@;
}

#network {
    color: #@ACCENT_ALT@;
}

#bluetooth {
    color: #@ACCENT_ALT@;
}

#bluetooth.disabled,
#bluetooth.off {
    color: #@MUTED@;
}

#pulseaudio {
    color: #@ACCENT_ALT@;
}

#pulseaudio.muted {
    color: #@MUTED@;
}

/* Toggle pills share one grammar: ENGAGED/active = solid accent fill
 * with dark text (legible regardless of how light the accent is);
 * idle/off = a muted glyph, no fill. Notifications-on and caffeine-on
 * are the "active" states. */
#custom-mako.on {
    color: #@BG_DEEP@;
    background-color: #@SUCCESS@;
    border-color: #@SUCCESS@;
}

#custom-mako.dnd {
    color: #@MUTED@;
}

#custom-caffeine.on {
    color: #@BG_DEEP@;
    background-color: #@WARNING@;
    border-color: #@WARNING@;
}

#custom-caffeine.off {
    color: #@MUTED@;
}

#custom-claude-usage.low {
    color: #@SUCCESS@;
}

#custom-claude-usage.medium {
    color: #@WARNING@;
}

#custom-claude-usage.high {
    color: #@ERROR@;
}

#custom-claude-usage.error {
    color: #@ERROR@;
}

#tray menu {
    background-color: rgba(@BG_R@, @BG_G@, @BG_B@, 0.95);
    color: #@FG@;
    border-radius: 10px;
    padding: 6px;
}

/* Power keeps its red tint but matches every other pill's metrics
 * (font-size, padding) so the bar's vertical baseline stays clean. */
#custom-power {
    color: #@ERROR@;
    background-color: rgba(@ERROR_R@, @ERROR_G@, @ERROR_B@, 0.14);
    border-color: rgba(@ERROR_R@, @ERROR_G@, @ERROR_B@, 0.32);
}

#custom-power:hover {
    color: #@BG_DEEP@;
    background-color: #@ERROR@;
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

/* Same story for the bell pair: bell-slash (U+F1F6, DND) renders a
 * notch smaller than the plain bell (U+F0F3, notifications on), so the
 * pill appeared to shrink when toggled off. Bump the DND glyph to match
 * the active bell — the "on" size is the correct one. */
#custom-mako.dnd {
    font-size: 18px;
}

/* ── Tooltips ─────────────────────────────────────────────────── */
tooltip {
    background-color: rgba(@BG_DEEP_R@, @BG_DEEP_G@, @BG_DEEP_B@, 0.95);
    border: 1px solid rgba(@ACCENT_R@, @ACCENT_G@, @ACCENT_B@, 0.4);
    border-radius: 10px;
    color: #@FG@;
}

tooltip label {
    padding: 4px;
}