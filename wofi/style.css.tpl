/* wofi launcher */

* {
    font-family: "JetBrainsMono Nerd Font", "JetBrains Mono", monospace;
    font-size: 13px;
}

window {
    background-color: rgba(@BG_R@, @BG_G@, @BG_B@, 0.85);
    border: 2px solid #@ACCENT@;
    border-radius: 14px;
}

#input {
    margin: 12px;
    padding: 8px 12px;
    border: none;
    border-radius: 10px;
    background-color: rgba(@SURFACE0_R@, @SURFACE0_G@, @SURFACE0_B@, 0.85);
    color: #@FG@;
    caret-color: #@ACCENT@;
}

#input image {
    color: #@FG_FAINT@;
}

#inner-box {
    margin: 0 8px 8px 8px;
}

#scroll {
    background: transparent;
}

#text {
    color: #@FG@;
    margin-left: 8px;
}

#entry {
    padding: 6px 12px;
    border-radius: 10px;
    background: transparent;
}

#entry image {
    -gtk-icon-transform: scale(0.9);
}

#entry:selected {
    background-color: rgba(@ACCENT_R@, @ACCENT_G@, @ACCENT_B@, 0.20);
    border: 1px solid #@ACCENT@;
}

#entry:selected #text {
    color: #ffffff;
}
