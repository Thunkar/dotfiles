/* wlogout overlay */

* {
    background-image: none;
    box-shadow: none;
    font-family: "JetBrainsMono Nerd Font", "Noto Sans", monospace;
    font-size: 16px;
    color: #@FG@;
}

window {
    background-color: rgba(@BG_DEEP_R@, @BG_DEEP_G@, @BG_DEEP_B@, 0.85);
}

button {
    color: #@FG@;
    background-color: rgba(@BG_R@, @BG_G@, @BG_B@, 0.85);
    border: 2px solid rgba(@ACCENT_R@, @ACCENT_G@, @ACCENT_B@, 0.30);
    border-radius: 18px;
    margin: 12px;
    background-repeat: no-repeat;
    background-position: center;
    background-size: 25%;
    transition: 200ms;
}

button:focus,
button:active,
button:hover {
    background-color: rgba(@ACCENT_R@, @ACCENT_G@, @ACCENT_B@, 0.18);
    border-color: #@ACCENT@;
    color: #ffffff;
    outline-style: none;
}

#lock {
    background-image: image(url("/usr/share/wlogout/icons/lock.png"));
}
#logout {
    background-image: image(url("/usr/share/wlogout/icons/logout.png"));
}
#suspend {
    background-image: image(url("/usr/share/wlogout/icons/suspend.png"));
}
#reboot {
    background-image: image(url("/usr/share/wlogout/icons/reboot.png"));
}
#shutdown {
    background-image: image(url("/usr/share/wlogout/icons/shutdown.png"));
}
