# dotfiles

Hyprland desktop for Arch. Wallpaper-driven theming: pick a wallpaper, and
the whole desktop (bar, terminal, notifications, launcher, lock screen,
login screen, GTK + Qt apps) recolours to match it via
[matugen](https://github.com/InioX/matugen) (Material You).

## Quick start

```sh
git clone <your-fork> ~/Repos/dotfiles
cd ~/Repos/dotfiles
./apply.sh                 # installs packages (pacman + AUR whitelist), deploys configs, themes
```

`./apply.sh` is idempotent — re-run it any time. Flags:

- `./apply.sh --no-install` — skip package installs, just redeploy configs.
- `./apply.sh hypr waybar` — only apply the named components.

After the first run, **log out and back in** so the Qt/GTK env, SDDM theme,
and login shell take effect.

## Per-machine setup (do this on each box)

Two things are intentionally machine-specific and won't be clobbered by
`git merge upstream` (protected via `.gitattributes merge=ours` /
`.gitignore`):

### 1. Monitors — `hypr/conf.d/10-monitors.conf`

Run `hyprctl monitors` to see your outputs, then edit the file:

```ini
monitor = DP-3,     2560x1440@240, 2560x0, 1
monitor = HDMI-A-1, 2560x1440@60,  0x0,    1

# Odd workspaces → $primary, even → $secondary
$primary   = DP-3
$secondary = HDMI-A-1
```

Single monitor? Point both at it: `$primary = eDP-1` / `$secondary = eDP-1`.

### 2. Wallpaper — `wallpapers/`

The wallpaper is the **seed for the entire colour theme**. Drop **one image**
(any format — jpg/png/webp) into `wallpapers/` and run `./apply.sh`:

```sh
cp ~/Downloads/space.jpg wallpapers/
./apply.sh --no-install        # normalises → default.png, re-themes everything
```

What happens:
1. `apply.sh` converts your image to `~/.config/hypr/wallpapers/default.png`.
2. `matugen` extracts a Material You palette from it → `theme/colors.env`.
3. Every `*.tpl` in the repo is rendered from those colours.
4. `swaybg` shows it on the desktop; `hyprlock` and SDDM blur it.

`wallpapers/` is gitignored, so your wallpaper stays local to the machine
(it's a binary and a personal choice). No wallpaper present → a neutral
gradient is generated as a fallback.

## How the theming works

```
wallpapers/<your image>
   └─ apply.sh: convert → ~/.config/hypr/wallpapers/default.png
        └─ matugen image  ─┬─→ theme/colors.env   (KEY=hex + KEY_R/_G/_B tokens)
                           │      └─ apply.sh renders every *.tpl from these
                           │         (waybar, mako, kitty, wofi, wlogout,
                           │          hyprlock, hypr borders, qt6ct/qt5ct, sddm)
                           └─→ ~/.config/gtk-{3,4}.0/colors.css  (GTK/libadwaita)
```

- **Single source of colour:** `theme/colors.env`. Don't hand-edit it —
  matugen regenerates it from the wallpaper. To tweak the palette, change
  the wallpaper (or, for a one-off, edit a `.tpl` directly).
- **Templates:** any file ending in `.tpl` is rendered by `apply.sh`
  (`@TOKEN@` → value from `colors.env`), dropping the `.tpl` suffix.
  Per-file overrides are fine — hardcode a literal next to a token, e.g.
  `rgba(@BASE_R@, @BASE_G@, @BASE_B@, 0.78)` to reuse a colour at custom alpha.
- **GTK:** `adw-gtk-theme` (adw-gtk3-dark) + matugen `colors.css`.
- **Qt:** `qt6ct`/`qt5ct` with the Fusion style + a palette rendered from
  `colors.env`. KDE Frameworks apps (Dolphin) are *not* themed on purpose —
  use the GTK equivalents (Nautilus).

## Adding software

Packages are split by trust, to limit exposure to AUR supply-chain attacks:

- **Repo packages → `packages.txt`** (one per line). Installed with plain
  `pacman` from the signed binary repos; **never built**. Must resolve via
  `pacman -Si <pkg>` — if it doesn't, `apply.sh` reports and skips it rather
  than silently building from the AUR.
- **AUR packages → `aur.txt`** (the build whitelist). The *only* names
  `apply.sh` will build via `yay`. Read the PKGBUILD first; keep the list
  short. Review diffs while building with `REVIEW_AUR=1 ./apply.sh`.
- **Flatpaks:** add the app ID to `flatpak.txt`, `./apply.sh`.

> Prefer the repo version of anything available there (e.g. CachyOS ships
> many AUR-ish `-git` packages as prebuilt signed binaries) — only put a
> name in `aur.txt` when no repo provides it.

## Components

| Area            | Tool / file                                    |
|-----------------|------------------------------------------------|
| Compositor      | Hyprland (`hypr/conf.d/*.conf`, sourced in order) |
| Bar             | waybar (`waybar/`)                             |
| Launcher        | wofi                                           |
| Notifications   | mako (click = focus app, right-click = dismiss)|
| Clipboard       | cliphist + wofi picker (`SUPER+V`)             |
| Wallpaper       | swaybg                                         |
| Lock / idle     | hyprlock + hypridle (caffeine toggle in bar)   |
| Login           | SDDM, self-contained theme in `sddm/theme/`    |
| Terminal        | kitty (`SUPER+Q`)                              |
| File manager    | Nautilus (`SUPER+E`)                           |
| Screenshots     | grim + slurp + satty (`Print`, `ALT+SHIFT+4/5`)|

`SUPER+/` opens a keybind cheatsheet generated from `# @cheat:` comments.
