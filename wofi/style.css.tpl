/* wofi launcher */

* {
    font-family: "JetBrainsMono Nerd Font", "JetBrains Mono", monospace;
    font-size: 13px;
}

window {
    background-color: rgba(@BASE_R@, @BASE_G@, @BASE_B@, 0.85);
    border: 2px solid #@MAUVE@;
    border-radius: 14px;
}

#input {
    margin: 12px;
    padding: 8px 12px;
    border: none;
    border-radius: 10px;
    background-color: rgba(@SURFACE0_R@, @SURFACE0_G@, @SURFACE0_B@, 0.85);
    color: #@TEXT@;
    caret-color: #@MAUVE@;
}

#input image {
    color: #@SUBTEXT0@;
}

#inner-box {
    margin: 0 8px 8px 8px;
}

#scroll {
    background: transparent;
}

#text {
    color: #@TEXT@;
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
    background-color: rgba(@MAUVE_R@, @MAUVE_G@, @MAUVE_B@, 0.20);
    border: 1px solid #@MAUVE@;
}

#entry:selected #text {
    color: #ffffff;
}
