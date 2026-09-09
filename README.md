# dotfiles

Hyprland desktop for Arch / CachyOS. Wallpaper-driven theming: pick a
wallpaper and the whole desktop (bar, terminal, notifications, launcher, lock
screen, login screen, GTK + Qt apps) recolours to match it via
[matugen](https://github.com/InioX/matugen) (Material You).

Hyprland is configured in **Lua** (`hypr/hyprland.lua`, Hyprland ≥ 0.55 — the
old hyprlang `.conf` format is deprecated and scheduled for removal), and the
session runs under **uwsm**, so every daemon is a systemd user unit.

## Quick start

```sh
git clone <your-fork> ~/Repos/dotfiles
cd ~/Repos/dotfiles
./apply.sh                 # packages (pacman + pinned AUR), configs, theme, SDDM
```

`./apply.sh` is idempotent — re-run it any time. Flags:

- `./apply.sh --no-install` — skip package installs (no sudo), redeploy configs.
- `./apply.sh hypr waybar` — only apply the named components.

Then **log out and pick the "Hyprland (uwsm)" session** in SDDM. uwsm launches
Hyprland as a systemd unit and brings up `graphical-session.target`, which is
what starts waybar, mako, hypridle, swaybg, cliphist, xsettingsd and the
polkit agent (all user units). Env vars come from `environment.d/`.

Migrating from the old `hyprland.conf`? The first apply keeps the legacy files
in place while your current session still uses them and tells you to
re-login; the next apply cleans them up.

## Per-machine setup (do this on each box)

Two things are machine-specific and gitignored, so they never end up in a
commit or an upstream PR:

### 1. Monitors — `hypr/machine.lua`

Run `hyprctl monitors` to see your outputs, then create the file:

```lua
hl.monitor({ output = "DP-3",     mode = "2560x1440@240", position = "2560x0", scale = 1 })
hl.monitor({ output = "HDMI-A-1", mode = "2560x1440@60",  position = "0x0",    scale = 1 })
return { primary = "DP-3", secondary = "HDMI-A-1" }
```

`primary` gets the odd workspaces and the SDDM login prompt, `secondary`
the even ones. Single monitor? Skip the file entirely: the catch-all in
`hypr/conf/monitors.lua` gives every output its preferred mode, and the
workspaces simply follow it. `primary` also tells SDDM which screen shows
the password prompt — the other screens only show the blurred wallpaper
(the theme's `Xsetup` marks it X11-primary).

Anything else machine-specific goes in `hypr/local.lua` (gitignored, loaded
last, may override anything).

### 2. Wallpaper — `wallpapers/`

The wallpaper is the **seed for the entire colour theme**. Drop **one image**
(jpg/png/webp…) into `wallpapers/` and run `./apply.sh`:

```sh
cp ~/Downloads/space.jpg wallpapers/
./apply.sh --no-install        # normalises → default.png, re-themes everything
./apply.sh                     # …also re-renders the SDDM login screen (needs sudo)
```

What happens:
1. `apply.sh` converts your image to `~/.config/hypr/wallpapers/default.png`.
2. `matugen` extracts a Material You palette from it → `theme/colors.env`.
3. Every `*.tpl` in the repo is rendered from those colours.
4. `swaybg` shows it; `hyprlock` and SDDM blur it.

`wallpapers/` is gitignored, so your wallpaper stays local. No wallpaper
present → a neutral gradient is generated as a fallback.

## How the theming works

```
wallpapers/<your image>
   └─ apply.sh: convert → ~/.config/hypr/wallpapers/default.png
        └─ matugen image  ─┬─→ theme/colors.env   (KEY=hex + KEY_R/_G/_B tokens)
                           │      └─ apply.sh renders every *.tpl from these
                           │         (waybar, mako, kitty, wofi, wlogout, hyprlock,
                           │          hypr/theme/colors.lua, qt6ct/qt5ct, sddm)
                           └─→ ~/.config/gtk-{3,4}.0/colors.css  (GTK/libadwaita)
```

- **Single source of colour:** `theme/colors.env`. Don't hand-edit it —
  matugen regenerates it from the wallpaper.
- **Templates:** any file ending in `.tpl` is rendered by `apply.sh`
  (`@TOKEN@` → value), dropping the suffix. Besides the colour tokens there
  are three built-ins: `@HOME@`, `@DOTFILES@` (this clone's path) and
  `@PRIMARY_OUTPUT@` (from `monitors.lua`). Literal overrides are fine inline,
  e.g. `rgba(@BASE_R@, @BASE_G@, @BASE_B@, 0.78)`.
- **Hyprland** reads the palette as a Lua table (`hypr/theme/colors.lua`,
  rendered from `colors.lua.tpl`) via `require("theme.colors")`.
- **GTK:** `adw-gtk-theme` (adw-gtk3-dark) + matugen `colors.css`.
- **Qt:** `qt6ct`/`qt5ct` with the Fusion style + a palette rendered from
  `colors.env`. KDE Frameworks apps are *not* themed on purpose — use the GTK
  equivalents (Nautilus).

## Hyprland config layout

```
hypr/hyprland.lua        entry point — requires the modules below in order
hypr/conf/monitors.lua   catch-all output + loads the per-machine hypr/machine.lua
hypr/conf/workspaces.lua odd → primary, even → secondary, all persistent
hypr/conf/look.lua       gaps, borders, blur, shadows, animations, layouts, misc
hypr/conf/input.lua      keyboard layout, mouse, gestures
hypr/conf/windowrules.lua
hypr/conf/keybinds.lua   binds; the "category | text" argument feeds the cheatsheet
hypr/conf/autostart.lua  compositor-side startup only (daemons are systemd units)
hypr/theme/colors.lua    GENERATED palette table
hypr/machine.lua         gitignored: your outputs + primary/secondary
hypr/local.lua           optional, gitignored, loaded last
```

Useful commands:

```sh
Hyprland --verify-config -c ~/.config/hypr/hyprland.lua   # validate (apply.sh does this)
hyprctl reload                                            # reload the live session
less /usr/share/hypr/stubs/hl.meta.lua                    # the hl.* API reference
```

`SUPER+F11` opens a keybind cheatsheet. It is generated from the running
compositor (`hyprctl binds -j`): every bind declared with a description of the
form `"category | text"` in `conf/keybinds.lua` shows up, grouped by category.

## Adding software

Packages are split by trust, to limit exposure to AUR supply-chain attacks:

- **Repo packages → `packages.txt`** (one per line). Installed with plain
  `pacman` from the signed binary repos; **never built**. Must resolve via
  `pacman -Si <pkg>` — otherwise `apply.sh` reports and skips it rather than
  building it from the AUR.
- **AUR packages → `aur.txt`**, each **pinned to a reviewed commit** of its
  AUR git repo: `<name> <commit>`. `apply.sh` clones the AUR repo, checks out
  exactly that commit and runs `makepkg` — no AUR helper, so a PKGBUILD that
  changed after you read it is never executed, and a commit that vanished
  from the AUR history (force-push, hijack) fails the build. To add or
  update: `./aur-review.sh <name>` shows the history, the diff since your
  pin and the PKGBUILD, then prints the line to paste.
- **Flatpaks:** add the app ID to `flatpak.txt`, `./apply.sh`.

Prefer the repo version of anything available there (CachyOS ships many
AUR-ish `-git` packages as signed binaries) — only pin something in `aur.txt`
when no repo provides it.

### Other safeguards in install mode

- `apply.sh` refuses to install while `/etc/pacman.conf` has a repo with
  `SigLevel = Optional TrustAll` (unverified packages). CachyOS repos are
  signed; remove the line. `ALLOW_UNSIGNED_REPOS=1` overrides.
- Installing is a full `pacman -Syu`, never `-Sy` + `-S`: refreshing the
  database and then installing without upgrading leads to partial upgrades.

## Printing and scanning

Driverless only: modern network printers speak IPP Everywhere / AirPrint, so
`cups` (enabled by `apply.sh`) discovers them over mDNS and shows a temporary
queue in every print dialog with no vendor driver installed. To pin a
permanent default queue for a printer that is on right now:

```sh
sudo lpadmin -p brother -E -m everywhere -v "$(ippfind -T 5 | head -1)"
sudo lpadmin -d brother
```

`system-config-printer` is the GTK GUI for queues and test pages. Scanning
is driverless too: `simple-scan` with the `sane-airscan` backend.

## Components

| Area            | Tool / file                                                    |
|-----------------|----------------------------------------------------------------|
| Session         | uwsm → Hyprland (Lua config in `hypr/`), user units in `systemd/user/` |
| Bar             | waybar (`waybar/`)                                             |
| Launcher        | wofi (`SUPER+SPACE`)                                           |
| Notifications   | mako (click = focus app, right-click = dismiss)                |
| Clipboard       | cliphist (cliphist.service) + wofi picker (`SUPER+V`)          |
| Wallpaper       | swaybg                                                         |
| Lock / idle     | hyprlock + hypridle (caffeine toggle in the bar)               |
| Login           | SDDM, self-contained theme in `sddm/theme/`, prompt on primary |
| Terminal        | kitty (`SUPER+Q`), dropdown on `F11` (native special workspace) |
| Power menu      | wlogout (`SUPER+M`, bar power pill)                            |
| File manager    | Nautilus (`SUPER+E`)                                           |
| Screenshots     | grim + slurp + satty (`Print`, `ALT+SHIFT+4/5`)                |
| Cheatsheet      | `SUPER+F11`, generated from bind descriptions                  |
| Printing        | CUPS driverless (IPP Everywhere), `system-config-printer`, `simple-scan` |
