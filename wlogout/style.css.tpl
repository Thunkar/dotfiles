/* wlogout — Catppuccin Mocha overlay */

* {
    background-image: none;
    box-shadow: none;
    font-family: "JetBrainsMono Nerd Font", "Noto Sans", monospace;
    font-size: 16px;
    color: #@TEXT@;
}

window {
    background-color: rgba(@CRUST_R@, @CRUST_G@, @CRUST_B@, 0.85);
}

button {
    color: #@TEXT@;
    background-color: rgba(@BASE_R@, @BASE_G@, @BASE_B@, 0.85);
    border: 2px solid rgba(@MAUVE_R@, @MAUVE_G@, @MAUVE_B@, 0.30);
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
    background-color: rgba(@MAUVE_R@, @MAUVE_G@, @MAUVE_B@, 0.18);
    border-color: #@MAUVE@;
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
