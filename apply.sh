#!/usr/bin/env bash
# apply.sh — install packages, deploy configs to ~/.config, and (re)start the
# session services that consume them. Idempotent: re-run it any time.
#
# Usage:
#   ./apply.sh                  install/upgrade packages, then apply everything
#   ./apply.sh --no-install …   skip package installs (no sudo needed)
#   ./apply.sh hypr waybar      apply only the named components
#
# Package policy (hardened against AUR supply-chain attacks):
#   packages.txt  REPO-ONLY. Installed with pacman from the signed binary
#                 repos, never built. Entries missing from every repo are
#                 reported and skipped — never silently built from the AUR.
#   aur.txt       The AUR whitelist: one "<name> <aur-git-commit>" per line.
#                 Built with makepkg from EXACTLY that commit of the package's
#                 AUR git repo (no AUR helper involved), so a PKGBUILD that
#                 changes after you reviewed it is never executed. Review and
#                 (re)pin with ./aur-review.sh <name>.
#   Install mode refuses to run while /etc/pacman.conf disables signature
#   checks (SigLevel … TrustAll) — see check_pacman_signatures.
#   Install mode does a full `pacman -Syu` before adding packages: refreshing
#   the sync DB and then installing without upgrading is the partial-upgrade
#   footgun Arch warns about.
#
# Session model: Hyprland is started by uwsm (the "Hyprland (uwsm)" SDDM
# session). Bars, daemons and the wallpaper are systemd user units bound to
# graphical-session.target (systemd/user/ + apply_systemd), not exec-once
# lines, and environment variables live in environment.d/.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() { sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; }

# ── arg parsing ─────────────────────────────────────────────────────
DO_INSTALL=1
TARGETS=()
for arg in "$@"; do
    case "$arg" in
        --no-install) DO_INSTALL=0 ;;
        -h|--help)    usage; exit 0 ;;
        *)            TARGETS+=("$arg") ;;
    esac
done

# `systemd` goes first: later handlers restart units it deploys/enables.
ALL_UTILITIES=(systemd hypr kitty waybar mako wofi wlogout xsettingsd autostart applications theme)
[[ ${#TARGETS[@]} -eq 0 ]] && TARGETS=("${ALL_UTILITIES[@]}")

step() { printf "\n\033[1;35m▸ %s\033[0m\n" "$*"; }
ok()   { printf "  \033[1;32m✓\033[0m %s\n" "$*"; }
warn() { printf "  \033[1;33m!\033[0m %s\n" "$*" >&2; }

# Non-comment, non-blank first fields of a manifest (packages.txt, aur.txt, …).
manifest_entries() { grep -vE '^\s*(#|$)' "$1" | awk '{print $1}'; }

# ── templates ───────────────────────────────────────────────────────
# Any file in the repo ending in .tpl is rendered by replacing @TOKEN@ with:
#   - every KEY=value from theme/colors.env (matugen output; falls back to
#     theme/colors.env.default on a fresh clone),
#   - the built-ins HOME, DOTFILES and PRIMARY_OUTPUT (the `primary` output
#     named in hypr/conf/monitors.lua, used by the SDDM theme).
# The .tpl suffix is dropped in the destination. Literal overrides are fine
# inline, e.g. rgba(@BASE_R@, @BASE_G@, @BASE_B@, 0.78).
TOKENS=()
primary_output() {
    grep -oP '^\s*primary\s*=\s*"\K[^"]+' "$DOTFILES_DIR/hypr/conf/monitors.lua" 2>/dev/null | head -1 || true
}
load_tokens() {
    (( ${#TOKENS[@]} )) && return 0   # cached for this run
    local env_file="$DOTFILES_DIR/theme/colors.env"
    [[ -f "$env_file" ]] || env_file="$DOTFILES_DIR/theme/colors.env.default"
    if [[ -f "$env_file" ]]; then
        local key value
        while IFS='=' read -r key value; do
            [[ "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]] || continue
            TOKENS+=(-e "s|@${key}@|${value}|g")
        done < "$env_file"
    fi
    TOKENS+=(-e "s|@HOME@|$HOME|g"
             -e "s|@DOTFILES@|$DOTFILES_DIR|g"
             -e "s|@PRIMARY_OUTPUT@|$(primary_output)|g")
}
render_file() {   # render_file <template> <output>
    load_tokens
    sed "${TOKENS[@]}" "$1" > "$2"
}
render_tpl_files() {   # render every *.tpl under <dir> in place
    local dest="$1" tpl
    while IFS= read -r -d '' tpl; do
        render_file "$tpl" "${tpl%.tpl}"
        rm -f "$tpl"
    done < <(find "$dest" -name '*.tpl' -type f -print0)
}

# sync_dir <src> <dest> [rsync-exclude ...]
#
# Mirrors src → dest with `rsync --delete`, so files removed from the repo
# are also removed from the destination, then renders templates. Files that
# legitimately live in dest but not in the repo (generated wallpaper, matugen
# colors.css, GTK bookmarks, …) MUST be passed as excludes or --delete wipes
# them. Only use this for directories the repo fully owns; for shared
# directories (autostart, systemd units, .desktop files) use copy_files.
sync_dir() {
    local src="$1" dest="$2"; shift 2
    mkdir -p "$dest"
    if command -v rsync >/dev/null 2>&1; then
        local ex=() pat
        for pat in "$@"; do ex+=("--exclude=$pat"); done
        rsync -a --delete "${ex[@]}" "$src"/ "$dest"/
    else
        cp -rT "$src" "$dest"   # additive fallback: leaves stale files behind
    fi
    render_tpl_files "$dest"
}

# copy_files <src-dir> <dest-dir>: additive copy (never deletes anything
# else living in dest), templates rendered.
copy_files() {
    local src="$1" dest="$2" f
    mkdir -p "$dest"
    for f in "$src"/*; do
        [[ -f "$f" ]] || continue
        if [[ "$f" == *.tpl ]]; then
            render_file "$f" "$dest/$(basename "${f%.tpl}")"
        else
            install -m 644 "$f" "$dest/"
        fi
    done
}

# ── session (systemd --user) helpers ────────────────────────────────
session_active() { systemctl --user is-active --quiet graphical-session.target 2>/dev/null; }
# unit_ctl <verb> <unit>: run a systemctl --user verb only inside a live
# graphical session (units are Requisite= on graphical-session.target).
unit_ctl() {
    session_active || return 0
    systemctl --user "$1" "$2.service" 2>/dev/null || warn "systemd: $1 $2 failed"
}

# ── sudo handling ───────────────────────────────────────────────────
# pacman/makepkg/chsh call sudo and --noconfirm doesn't cover the password
# prompt. Prime the timestamp once, keep it alive until the script exits.
SUDO_KEEPER_PID=""
prime_sudo() {
    step "this run needs sudo (pacman/makepkg/chsh/sddm) — authenticate once"
    sudo -v
    ( while true; do sudo -n true 2>/dev/null || exit; sleep 60; done ) &
    SUDO_KEEPER_PID=$!
    trap 'if [[ -n "$SUDO_KEEPER_PID" ]]; then kill "$SUDO_KEEPER_PID" 2>/dev/null || true; fi' EXIT
}

# ── packages ────────────────────────────────────────────────────────
# Refuse to install anything while a repo has signature checking disabled:
# with `SigLevel = Optional TrustAll` every package from that repo is
# installed unverified, so a bad mirror (or a MITM) can hand you anything.
check_pacman_signatures() {
    local bad
    bad=$(awk '/^[[:space:]]*\[/ { sec = $0 }
               /^[[:space:]]*SigLevel[[:space:]]*=.*TrustAll/ { print sec }' /etc/pacman.conf)
    [[ -z "$bad" ]] && return 0
    warn "pacman: signature checking is DISABLED (SigLevel … TrustAll) in /etc/pacman.conf for: $(tr '\n' ' ' <<<"$bad")"
    warn "        Packages from there install unverified. CachyOS repos ARE signed and the key is"
    warn "        in your keyring — delete that SigLevel line (compare /etc/pacman.conf.pacnew)."
    [[ -n "${ALLOW_UNSIGNED_REPOS:-}" ]] && { warn "        ALLOW_UNSIGNED_REPOS set — continuing anyway."; return 0; }
    warn "        Refusing to install packages (set ALLOW_UNSIGNED_REPOS=1 to override)."
    exit 1
}

# packages.txt → pacman, from the configured binary repos only. Anything not
# in a repo is reported and left out — it could be a name squatted in the AUR.
install_packages() {
    [[ -f "$DOTFILES_DIR/packages.txt" ]] || return 0
    local pkgs
    mapfile -t pkgs < <(manifest_entries "$DOTFILES_DIR/packages.txt")
    (( ${#pkgs[@]} )) || return 0

    step "refreshing pacman databases"
    sudo pacman -Sy --noconfirm >/dev/null

    local install=() missing=() p
    for p in "${pkgs[@]}"; do
        if pacman -Si "$p" >/dev/null 2>&1; then install+=("$p"); else missing+=("$p"); fi
    done
    if (( ${#missing[@]} )); then
        warn "${#missing[@]} packages.txt entries are in NO configured repo — skipped, NOT built from the AUR:"
        printf '         - %s\n' "${missing[@]}" >&2
        warn "if one genuinely lives in the AUR: ./aur-review.sh <name>, then add it to aur.txt"
    fi
    (( ${#install[@]} )) || { warn "no repo packages to install"; return 0; }

    step "system upgrade + ${#install[@]} repo packages via pacman (no AUR)"
    sudo pacman -Su --needed --noconfirm "${install[@]}"
    ok "repo packages OK"
}

# aur.txt → makepkg, pinned. Each line is "<name> <40-hex AUR git commit>".
# The AUR repo is cloned, that exact commit is checked out (a commit that is
# no longer in the AUR history — force-push, hijack — fails the build), and
# makepkg builds + installs it. No AUR helper, so nothing ever "helpfully"
# resolves a same-named package or pulls a newer PKGBUILD. Unpinned entries
# are skipped with instructions. Built pins are remembered under
# $XDG_STATE_HOME/dotfiles/aur so re-runs are no-ops until you re-pin.
install_aur() {
    [[ -f "$DOTFILES_DIR/aur.txt" ]] || return 0
    local entries
    mapfile -t entries < <(grep -vE '^\s*(#|$)' "$DOTFILES_DIR/aur.txt" | awk '{print $1, $2}')
    (( ${#entries[@]} )) || return 0

    local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/aur"
    mkdir -p "$state_dir"
    local entry name sha built
    for entry in "${entries[@]}"; do
        read -r name sha <<<"$entry"
        if [[ ! "$sha" =~ ^[0-9a-f]{40}$ ]]; then
            warn "aur.txt: '$name' has no commit pin — skipped. Review + pin it with: ./aur-review.sh $name"
            continue
        fi
        built="$(cat "$state_dir/$name" 2>/dev/null || true)"
        if [[ "$built" == "$sha" ]] && pacman -Q "$name" >/dev/null 2>&1; then
            ok "aur: $name already built from pinned ${sha:0:12}"
            continue
        fi
        build_aur_pinned "$name" "$sha" && printf '%s\n' "$sha" > "$state_dir/$name"
    done
}
build_aur_pinned() {
    local name="$1" sha="$2" tmp
    tmp="$(mktemp -d)"
    step "aur: building $name from AUR commit ${sha:0:12} (pinned)"
    if ! git clone --quiet "https://aur.archlinux.org/$name.git" "$tmp/$name"; then
        warn "aur: could not clone $name from the AUR"; rm -rf "$tmp"; return 1
    fi
    if ! git -C "$tmp/$name" checkout --quiet --detach "$sha" 2>/dev/null \
       || [[ "$(git -C "$tmp/$name" rev-parse HEAD)" != "$sha" ]]; then
        warn "aur: pinned commit $sha is not in $name's AUR history (rewritten? typo?) — NOT building"
        rm -rf "$tmp"; return 1
    fi
    local upstream
    upstream="$(git -C "$tmp/$name" rev-parse origin/HEAD 2>/dev/null || true)"
    [[ -n "$upstream" && "$upstream" != "$sha" ]] \
        && warn "aur: $name has newer AUR commits than the pin — review them with ./aur-review.sh $name"
    if (cd "$tmp/$name" && makepkg -si --needed --noconfirm --rmdeps --clean); then
        rm -rf "$tmp"
        ok "aur: $name installed"
        return 0
    fi
    warn "aur: build failed for $name (tree kept at $tmp for inspection)"
    return 1
}

# flatpak.txt: one app ID per line, installed user-scoped (no sudo).
install_flatpaks() {
    [[ -f "$DOTFILES_DIR/flatpak.txt" ]] || return 0
    command -v flatpak >/dev/null 2>&1 || { warn "flatpak not installed — skipping flatpak.txt"; return 0; }
    local apps
    mapfile -t apps < <(manifest_entries "$DOTFILES_DIR/flatpak.txt")
    (( ${#apps[@]} )) || return 0
    step "ensuring flathub remote (--user)"
    flatpak remote-add --if-not-exists --user flathub \
        https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || true
    step "installing/updating ${#apps[@]} flatpak apps"
    flatpak install --user --noninteractive --or-update flathub "${apps[@]}"
    ok "flatpaks OK"
}

# ── system-level ensure_* (need sudo → install mode only) ───────────
ensure_zsh_login_shell() {
    local current; current="$(getent passwd "$USER" | cut -d: -f7)"
    if [[ "$current" != *zsh ]]; then
        step "switching login shell to zsh"
        chsh -s /usr/bin/zsh "$USER"
        ok "login shell now zsh (re-login required)"
    fi
}

ensure_bluetooth_service() {
    # waybar's bluetooth module talks to bluez over D-Bus; bluetoothd must run.
    if systemctl list-unit-files bluetooth.service >/dev/null 2>&1; then
        sudo systemctl enable --now bluetooth.service >/dev/null 2>&1 || true
    fi
}

ensure_sddm_theme() {
    # Self-contained SDDM theme from sddm/theme/ → /usr/share/sddm/themes/dotfiles/.
    # theme.conf (palette) and Xsetup (primary output) are rendered from tokens,
    # so this must run AFTER generate_palette to pick up the current wallpaper.
    [[ -d "$DOTFILES_DIR/sddm/theme" ]] || return 0
    command -v sddm >/dev/null 2>&1 || { warn "sddm not installed — skipping theme"; return 0; }

    local dest=/usr/share/sddm/themes/dotfiles tmp
    sudo rm -rf "$dest"
    sudo mkdir -p "$dest"
    sudo cp -rT "$DOTFILES_DIR/sddm/theme" "$dest"
    sudo rm -f "$dest"/*.tpl

    tmp="$(mktemp -d)"
    render_file "$DOTFILES_DIR/sddm/theme/theme.conf.tpl" "$tmp/theme.conf"
    render_file "$DOTFILES_DIR/sddm/theme/Xsetup.tpl"     "$tmp/Xsetup"
    sudo install -m 644 "$tmp/theme.conf" "$dest/theme.conf"
    sudo install -m 755 "$tmp/Xsetup"     "$dest/Xsetup"
    rm -rf "$tmp"

    # Blurred login background from the desktop wallpaper (imagemagick at
    # install time — no QML GraphicalEffects dependency).
    local wp="$HOME/.config/hypr/wallpapers/default.png" bg
    if [[ -f "$wp" ]] && command -v magick >/dev/null 2>&1; then
        bg="$(mktemp --suffix=.png)"
        magick "$wp" -resize 2560x -blur 0x18 -modulate 70 "$bg" 2>/dev/null \
            && sudo install -m 644 "$bg" "$dest/background.png"
        rm -f "$bg"
    elif [[ -f "$wp" ]]; then
        sudo install -m 644 "$wp" "$dest/background.png"   # unblurred fallback
    fi

    sudo mkdir -p /etc/sddm.conf.d
    printf '[Theme]\nCurrent=dotfiles\n\n[X11]\n# Marks the Hyprland primary output as X11 primary so the login prompt lands there.\nDisplayCommand=%s/Xsetup\n' "$dest" \
        | sudo tee /etc/sddm.conf.d/10-theme.conf >/dev/null
    sudo rm -f /etc/sddm.conf.d/10-catppuccin.conf

    ok "sddm: theme installed (palette from colors.env; login prompt on ${PRIMARY:-$(primary_output)})"
}

# ── user-level ensure_* ─────────────────────────────────────────────
ensure_git_merge_driver() {
    # .gitattributes marks hypr/conf/monitors.lua merge=ours so `git merge
    # upstream` keeps this machine's layout; the driver is per-clone config.
    [[ -d "$DOTFILES_DIR/.git" ]] || return 0
    git -C "$DOTFILES_DIR" config merge.ours.driver true 2>/dev/null || true
}

# Keep Firefox the default browser (Chromium grabs it on install).
ensure_default_browser() {
    command -v xdg-settings >/dev/null 2>&1 || return 0
    [[ -f /usr/share/applications/firefox.desktop ]] || return 0
    [[ "$(xdg-settings get default-web-browser 2>/dev/null)" == "firefox.desktop" ]] && return 0
    xdg-settings set default-web-browser firefox.desktop 2>/dev/null || true
    local s
    for s in x-scheme-handler/http x-scheme-handler/https text/html; do
        xdg-mime default firefox.desktop "$s" 2>/dev/null || true
    done
    ok "browser: default set to Firefox"
}

ensure_default_wallpaper() {
    # Normalise the wallpaper to ~/.config/hypr/wallpapers/default.png — the
    # seed of the whole theme: swaybg shows it, hyprlock and SDDM blur it,
    # matugen derives the palette from it. Source = first image in the
    # repo's (gitignored) wallpapers/ dir, converted to real PNG.
    local wp_dir="$HOME/.config/hypr/wallpapers" dest src
    dest="$wp_dir/default.png"
    mkdir -p "$wp_dir"
    src="$(find "$DOTFILES_DIR/wallpapers" -maxdepth 1 -type f ! -name '.gitkeep' 2>/dev/null | head -1)"

    if [[ -n "$src" ]]; then
        if command -v magick >/dev/null 2>&1; then
            magick "$src" "$dest"
        elif command -v convert >/dev/null 2>&1; then
            convert "$src" "$dest"
        else
            install -m 644 "$src" "$dest"    # last resort (assumes PNG)
        fi
        ok "wallpaper: $(basename "$src") → default.png"
    elif [[ ! -f "$dest" ]]; then
        if command -v magick >/dev/null 2>&1; then
            magick -size 3840x2160 gradient:'#11111b-#1e1e2e' "$dest"
            warn "no wallpaper in wallpapers/ — generated a placeholder gradient"
        else
            warn "no wallpaper in wallpapers/ and no imagemagick — set one manually at $dest"
        fi
    fi
}

# matugen config + templates → ~/.config/matugen (config.toml.tpl carries
# @DOTFILES@ so its output lands in this clone's theme/ dir).
sync_matugen() { sync_dir "$DOTFILES_DIR/matugen" "$HOME/.config/matugen"; }

# Wallpaper → palette. matugen regenerates theme/colors.env (consumed by every
# .tpl) and ~/.config/gtk-{3,4}.0/colors.css. Runs BEFORE any template render.
# Output is validated (no template markers left behind); on failure the
# previous colors.env is kept so the desktop never gets a broken palette.
WALLPAPER_DEST="$HOME/.config/hypr/wallpapers/default.png"
generate_palette() {
    [[ -f "$WALLPAPER_DEST" ]] || return 0
    command -v matugen >/dev/null 2>&1 || {
        warn "matugen not installed — using committed theme/colors.env as-is"
        return 0
    }
    sync_matugen

    local env_file="$DOTFILES_DIR/theme/colors.env" backup
    backup="$(mktemp)"
    cp "$env_file" "$backup" 2>/dev/null || true

    # --prefer saturation: with several candidate source colours pick the most
    # saturated (no TTY to ask) — a vivid accent rather than a muddy average.
    if matugen --config "$HOME/.config/matugen/config.toml" \
               --mode dark --prefer saturation \
               image "$WALLPAPER_DEST" >/dev/null 2>&1 \
       && ! grep -q '{{' "$env_file" 2>/dev/null; then
        ok "matugen: palette regenerated from $(basename "$WALLPAPER_DEST")"
    else
        cp "$backup" "$env_file" 2>/dev/null || true
        warn "matugen: generation failed — kept previous colors.env"
    fi
    rm -f "$backup"
    TOKENS=()   # drop the cached tokens so the new palette is what gets rendered
}

# ── per-component handlers ──────────────────────────────────────────

# Session daemons as systemd user units. Package-shipped units are used where
# usable (waybar, mako, hypridle, cliphist, hyprpolkitagent); systemd/user/
# carries ours for swaybg (ships none) and xsettingsd (the shipped one has no
# [Install] and reads ~/.xsettingsd). cliphist's single untyped watcher stores
# text and images alike (verified). Units are copied one by one — never
# mirrored — because ~/.config/systemd/user also holds enablement symlinks
# and units from other software.
SESSION_UNITS=(hyprpolkitagent waybar mako hypridle cliphist xsettingsd swaybg)
apply_systemd() {
    # Units whose file changed need a restart to pick up the new ExecStart.
    local changed=() f dest="$HOME/.config/systemd/user"
    for f in "$DOTFILES_DIR"/systemd/user/*.service; do
        cmp -s "$f" "$dest/$(basename "$f")" 2>/dev/null || changed+=("$(basename "${f%.service}")")
    done
    copy_files "$DOTFILES_DIR/systemd/user" "$dest"
    systemctl --user daemon-reload 2>/dev/null || true
    local u
    for u in "${SESSION_UNITS[@]}"; do
        if ! systemctl --user list-unit-files "$u.service" >/dev/null 2>&1; then
            warn "systemd: $u.service not found (package not installed?)"
            continue
        fi
        systemctl --user enable "$u.service" >/dev/null 2>&1 || warn "systemd: could not enable $u.service"
    done
    session_active || { ok "systemd: session units enabled (they start at next login)"; return 0; }
    adopt_unmanaged_daemons
    for u in "${changed[@]}"; do
        systemctl --user is-active --quiet "$u.service" 2>/dev/null \
            && { systemctl --user restart "$u.service" 2>/dev/null || warn "systemd: could not restart $u.service"; }
    done
    for u in "${SESSION_UNITS[@]}"; do
        systemctl --user is-active --quiet "$u.service" 2>/dev/null && continue
        systemctl --user start "$u.service" 2>/dev/null || warn "systemd: could not start $u.service"
    done
    ok "systemd: session units enabled + running${changed[*]:+ (restarted: ${changed[*]})}"
}
# A daemon started outside systemd (an exec-once from the pre-uwsm config,
# or by hand) would race its unit; stop such copies before starting units.
adopt_unmanaged_daemons() {
    local u
    for u in waybar mako hypridle xsettingsd swaybg; do
        systemctl --user is-active --quiet "$u.service" 2>/dev/null && continue
        pkill -x "$u" 2>/dev/null || true
    done
    systemctl --user is-active --quiet cliphist.service 2>/dev/null \
        || pkill -f '^(/usr/bin/)?wl-paste .*--watch cliphist store' 2>/dev/null || true   # anchored: never match a shell quoting this line
}

# The running compositor started with the legacy hyprland.conf? (Only the
# config type present at startup is ever loaded; a reload re-reads the same
# file.) Then the hyprlang files must survive this sync and a re-login is
# needed to pick up hyprland.lua.
hypr_running_legacy() {
    pgrep -x Hyprland >/dev/null 2>&1 || return 1
    local log="${XDG_RUNTIME_DIR:-/run/user/$UID}/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-none}/hyprland.log"
    [[ -f "$log" ]] && grep -q 'using legacy config' "$log"
}
verify_hypr_config() {
    local result
    result="$(Hyprland --verify-config -c "$HOME/.config/hypr/hyprland.lua" 2>&1 \
              | sed -n '/Config parsing result/,$p' | tail -n +2 | grep -v '^\s*$' || true)"
    [[ "$result" == "config ok" ]] && return 0
    warn "hypr: hyprland.lua has errors — not reloading:"
    printf '         %s\n' "$result" >&2
    return 1
}
apply_hypr() {
    # wallpapers/ (generated) and local.lua (per-machine, gitignored) are not
    # in the repo and must survive --delete.
    local ex=(wallpapers local.lua) legacy=0
    if hypr_running_legacy; then
        legacy=1
        ex+=(hyprland.conf conf.d theme/colors.conf)   # still in use by the running session
    fi
    sync_dir "$DOTFILES_DIR/hypr" "$HOME/.config/hypr" "${ex[@]}"

    if ! command -v Hyprland >/dev/null 2>&1; then
        ok "hypr: applied (Hyprland not installed here)"
        return 0
    fi
    verify_hypr_config || return 0

    if (( legacy )); then
        warn "hypr: the running session was started from the legacy hyprland.conf — log out and back in to load hyprland.lua (legacy files kept until then)"
    elif pgrep -x Hyprland >/dev/null 2>&1; then
        hyprctl reload >/dev/null
        migrate_workspaces_to_rules
        ok "hypr: applied + reloaded"
    else
        ok "hypr: applied (no running session to reload)"
    fi
    unit_ctl restart swaybg   # show a changed wallpaper without re-login
}

# `hyprctl reload` updates workspace rules but does not move existing
# workspaces to their (new) monitors; do it so the live session matches.
migrate_workspaces_to_rules() {
    command -v jq >/dev/null 2>&1 || return 0
    local ws mon
    while read -r ws mon; do
        [[ -n "$ws" && -n "$mon" ]] || continue
        hyprctl dispatch moveworkspacetomonitor "$ws" "$mon" >/dev/null 2>&1 || true
    done < <(hyprctl -j workspacerules 2>/dev/null \
             | jq -r '.[] | select((.monitor // "") != "")
                          | select(.workspaceString | test("^([0-9]+|special:.*)$"))
                          | "\(.workspaceString) \(.monitor)"' 2>/dev/null || true)
}

apply_kitty() {
    sync_dir "$DOTFILES_DIR/kitty" "$HOME/.config/kitty"
    pkill -USR1 -x kitty 2>/dev/null || true   # live config reload
    ok "kitty: applied"
}

apply_waybar() {
    sync_dir "$DOTFILES_DIR/waybar" "$HOME/.config/waybar"
    unit_ctl restart waybar
    ok "waybar: applied + restarted"
}

apply_mako() {
    sync_dir "$DOTFILES_DIR/mako" "$HOME/.config/mako"
    unit_ctl reload-or-restart mako   # ExecReload=makoctl reload keeps the queue
    ok "mako: applied"
}

apply_wofi() {
    sync_dir "$DOTFILES_DIR/wofi" "$HOME/.config/wofi"
    ok "wofi: applied"
}

apply_wlogout() {
    sync_dir "$DOTFILES_DIR/wlogout" "$HOME/.config/wlogout"
    ok "wlogout: applied"
}

apply_xsettingsd() {
    sync_dir "$DOTFILES_DIR/xsettingsd" "$HOME/.config/xsettingsd"
    unit_ctl reload-or-restart xsettingsd
    ok "xsettingsd: applied"
}

# User-side autostart overrides: XDG says ~/.config/autostart/ supersedes
# /etc/xdg/autostart/, so these Hidden=true entries suppress nm-applet and
# blueman-applet (their tray icons duplicate waybar's network/bluetooth
# modules). Additive copy — other apps (1Password, …) keep their entries here.
apply_autostart() {
    copy_files "$DOTFILES_DIR/autostart" "$HOME/.config/autostart"
    pkill -x nm-applet 2>/dev/null || true
    pkill -f blueman-applet 2>/dev/null || true
    pkill -f blueman-tray 2>/dev/null || true
    ok "autostart: suppressed redundant tray applets"
}

# Per-app .desktop overrides (applications/, if present) + URI-scheme handlers.
# ~/.local/share/applications holds user-installed entries (wine, web apps…),
# so copies are additive.
apply_applications() {
    if [[ -d "$DOTFILES_DIR/applications" ]]; then
        copy_files "$DOTFILES_DIR/applications" "$HOME/.local/share/applications"
    fi
    command -v update-desktop-database >/dev/null 2>&1 \
        && update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

    # Printables' "Open in PrusaSlicer" emits prusaslicer:// URIs; prefer the
    # Flatpak, fall back to the packaged app.
    command -v xdg-mime >/dev/null 2>&1 || return 0
    local prusa_desktop=""
    if [[ -f /var/lib/flatpak/exports/share/applications/com.prusa3d.PrusaSlicer.desktop \
       || -f "$HOME/.local/share/flatpak/exports/share/applications/com.prusa3d.PrusaSlicer.desktop" ]]; then
        prusa_desktop="com.prusa3d.PrusaSlicer.desktop"
    elif [[ -f /usr/share/applications/PrusaSlicer.desktop ]]; then
        prusa_desktop="PrusaSlicer.desktop"
    fi
    if [[ -n "$prusa_desktop" ]]; then
        xdg-mime default "$prusa_desktop" x-scheme-handler/prusaslicer 2>/dev/null || true
        ok "applications: registered prusaslicer:// → $prusa_desktop"
    fi
}

# GTK + minimal Qt theming + session env. GTK is the primary target; Qt apps
# get a Fusion palette via qt6ct/qt5ct. KDE Frameworks apps stay un-themed on
# purpose (see packages.txt).
apply_theme() {
    sync_dir "$DOTFILES_DIR/qt6ct" "$HOME/.config/qt6ct"
    sync_dir "$DOTFILES_DIR/qt5ct" "$HOME/.config/qt5ct"
    # colors.css is matugen's; bookmarks/servers belong to Nautilus.
    sync_dir "$DOTFILES_DIR/gtk-3.0" "$HOME/.config/gtk-3.0" colors.css bookmarks servers
    sync_dir "$DOTFILES_DIR/gtk-4.0" "$HOME/.config/gtk-4.0" colors.css bookmarks servers
    sync_dir "$DOTFILES_DIR/environment.d" "$HOME/.config/environment.d"
    sync_matugen

    # environment.d is re-read by the user manager on daemon-reload; already
    # running processes (and the compositor) keep their env until re-login.
    systemctl --user daemon-reload 2>/dev/null || true

    if command -v gsettings >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.interface gtk-theme    "adw-gtk3-dark" 2>/dev/null || true
        gsettings set org.gnome.desktop.interface icon-theme   "Papirus-Dark"  2>/dev/null || true
        gsettings set org.gnome.desktop.interface cursor-theme "Adwaita"       2>/dev/null || true
        gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"   2>/dev/null || true
        gsettings set org.gnome.desktop.interface font-name    "Noto Sans 11"  2>/dev/null || true
    fi
    ok "theme: GTK/Qt/env applied"
}

# ── run ─────────────────────────────────────────────────────────────
if (( DO_INSTALL )); then
    prime_sudo
    check_pacman_signatures
    install_packages
    install_aur
    install_flatpaks
    ensure_zsh_login_shell
    ensure_bluetooth_service
fi

ensure_git_merge_driver
ensure_default_browser
ensure_default_wallpaper

step "generating palette from wallpaper"
generate_palette

# Needs sudo and the fresh palette, hence here rather than with the installs.
(( DO_INSTALL )) && ensure_sddm_theme

step "applying configs: ${TARGETS[*]}"
for util in "${TARGETS[@]}"; do
    if ! declare -f "apply_$util" >/dev/null; then
        warn "$util: no handler defined, skipping"
        continue
    fi
    # `theme` and `applications` are meta-handlers without a same-named dir.
    if [[ "$util" != "theme" && "$util" != "applications" && ! -d "$DOTFILES_DIR/$util" ]]; then
        warn "$util: directory not found in repo, skipping"
        continue
    fi
    "apply_$util"
done

step "done"
