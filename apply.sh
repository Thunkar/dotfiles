#!/usr/bin/env bash
# apply.sh — install dependencies via yay, copy configs to ~/.config,
# and reload running services.
#
# Usage:
#   ./apply.sh                  # install deps + apply every utility
#   ./apply.sh hypr waybar      # apply only the listed utilities
#   ./apply.sh --no-install …   # skip dep install / yay bootstrap
#
# Environment:
#   CLAUDE_PLAN=pro|max5|max20  exposed to waybar's claude-usage widget
#                               (defaults to "pro" if unset)

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── arg parsing ─────────────────────────────────────────────────────
DO_INSTALL=1
TARGETS=()
for arg in "$@"; do
    case "$arg" in
        --no-install) DO_INSTALL=0 ;;
        -h|--help)
            sed -n '2,12p' "$0"
            exit 0
            ;;
        *) TARGETS+=("$arg") ;;
    esac
done

ALL_UTILITIES=(hypr hyprpaper kitty waybar mako wofi wlogout xsettingsd autostart applications theme)
[[ ${#TARGETS[@]} -eq 0 ]] && TARGETS=("${ALL_UTILITIES[@]}")

step() { printf "\n\033[1;35m▸ %s\033[0m\n" "$*"; }
ok()   { printf "  \033[1;32m✓\033[0m %s\n" "$*"; }
warn() { printf "  \033[1;33m!\033[0m %s\n" "$*"; }

# ── sudo handling ───────────────────────────────────────────────────
# yay/pacman/makepkg/chsh all call sudo, and --noconfirm doesn't help
# with the password prompt itself. Prime the sudo timestamp once
# (interactively), then keep it alive in the background while we work.
SUDO_KEEPER_PID=""
prime_sudo() {
    step "this run needs sudo (pacman/yay/chsh) — authenticate once"
    sudo -v
    # Refresh timestamp every 60s until this script exits.
    ( while true; do sudo -n true 2>/dev/null || exit; sleep 60; done ) &
    SUDO_KEEPER_PID=$!
    trap 'if [[ -n "$SUDO_KEEPER_PID" ]]; then kill "$SUDO_KEEPER_PID" 2>/dev/null || true; fi' EXIT
}

# ── yay bootstrap ───────────────────────────────────────────────────
bootstrap_yay() {
    if command -v yay >/dev/null 2>&1; then
        return 0
    fi
    step "yay not found — bootstrapping from AUR"
    sudo pacman -S --needed --noconfirm git base-devel
    local tmp; tmp="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
    ok "yay installed"
}

# AUR packages with broken PKGBUILDs sometimes invoke build tools they
# never declared. Install these unconditionally before the main pass so
# yay-driven makepkg never trips over a missing binary.
BUILD_DEPS=(scdoc)

install_packages() {
    [[ -f "$DOTFILES_DIR/packages.txt" ]] || return 0
    local pkgs
    mapfile -t pkgs < <(grep -vE '^\s*(#|$)' "$DOTFILES_DIR/packages.txt" | awk '{print $1}')
    [[ ${#pkgs[@]} -eq 0 ]] && return 0

    step "ensuring AUR build tools: ${BUILD_DEPS[*]}"
    sudo pacman -S --needed --noconfirm "${BUILD_DEPS[@]}"

    # Clear any half-built AUR cache from previous failed runs so yay
    # rebuilds from a clean tree (avoids "existing $srcdir/ tree" gotchas).
    rm -rf "$HOME/.cache/yay/hdrop-git/src" 2>/dev/null || true

    step "installing/updating ${#pkgs[@]} packages via yay"
    # --answerclean / --answerdiff suppress the interactive build prompts
    # for AUR packages that have already been built locally.
    yay -S --needed --noconfirm \
        --answerclean N --answerdiff N --removemake \
        "${pkgs[@]}"
    ok "packages OK"
}

# Flatpak app management. flatpak.txt is one app ID per line, comments
# stripped. Installs user-scoped (no sudo) into ~/.local/share/flatpak/.
install_flatpaks() {
    [[ -f "$DOTFILES_DIR/flatpak.txt" ]] || return 0
    command -v flatpak >/dev/null 2>&1 || {
        warn "flatpak not installed — skipping flatpak.txt"
        return 0
    }
    local apps
    mapfile -t apps < <(grep -vE '^\s*(#|$)' "$DOTFILES_DIR/flatpak.txt" | awk '{print $1}')
    [[ ${#apps[@]} -eq 0 ]] && return 0

    step "ensuring flathub remote (--user)"
    flatpak remote-add --if-not-exists --user flathub \
        https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || true

    step "installing/updating ${#apps[@]} flatpak apps"
    flatpak install --user --noninteractive --or-update flathub "${apps[@]}"
    ok "flatpaks OK"
}

ensure_zsh_login_shell() {
    local current; current="$(getent passwd "$USER" | cut -d: -f7)"
    if [[ "$current" != *zsh ]]; then
        step "switching login shell to zsh"
        chsh -s /usr/bin/zsh "$USER"
        ok "login shell now zsh (re-login required)"
    fi
}

ensure_screenshot_dir() {
    mkdir -p "$HOME/Pictures/Screenshots"
}

ensure_git_merge_driver() {
    # .gitattributes marks hypr/conf.d/10-monitors.conf as merge=ours so
    # `git merge upstream` keeps this machine's monitor layout. The
    # driver itself is per-clone local config — register it here.
    [[ -d "$DOTFILES_DIR/.git" ]] || return 0
    git -C "$DOTFILES_DIR" config merge.ours.driver true 2>/dev/null || true
}

ensure_bluetooth_service() {
    # The waybar bluetooth module talks to bluez over D-Bus, which only
    # works once bluetoothd is running. Enable + start the system unit
    # so it survives reboots and is up for the first apply.
    if systemctl list-unit-files bluetooth.service >/dev/null 2>&1; then
        sudo systemctl enable --now bluetooth.service >/dev/null 2>&1 || true
    fi
}

# Wallpaper-driven palette generation. This is the SOURCE of the whole
# theme: matugen extracts a Material You palette from the wallpaper and
# regenerates BOTH theme/colors.env (consumed by every .tpl in the repo
# via the sed pipeline) AND ~/.config/gtk-{3,4}.0/colors.css (libadwaita
# overrides for GTK apps).
#
# Must run BEFORE any sync_dir / .tpl rendering so the fresh colors.env
# is what gets rendered. Validates the generated colors.env (rejects it
# if matugen left template markers behind) and keeps the previous
# committed colors.env on any failure — the desktop never ends up with
# a broken palette.
WALLPAPER_DEST="$HOME/.config/hypr/wallpapers/default.png"
generate_palette() {
    [[ -f "$WALLPAPER_DEST" ]] || return 0
    command -v matugen >/dev/null 2>&1 || {
        warn "matugen not installed — using committed theme/colors.env as-is"
        return 0
    }
    # Sync the matugen config + templates first so matugen can find them.
    sync_dir "$DOTFILES_DIR/matugen" "$HOME/.config/matugen"

    local env_file="$DOTFILES_DIR/theme/colors.env"
    local backup; backup="$(mktemp)"
    cp "$env_file" "$backup" 2>/dev/null || true

    # --prefer saturation: when matugen finds several candidate source
    # colors it picks the most saturated one (no TTY here, so it can't
    # prompt). Gives a vivid accent rather than a muddy average.
    if matugen --config "$HOME/.config/matugen/config.toml" \
               --mode dark \
               --prefer saturation \
               image "$WALLPAPER_DEST" >/dev/null 2>&1 \
       && ! grep -q '{{' "$env_file" 2>/dev/null; then
        ok "matugen: palette regenerated from $(basename "$WALLPAPER_DEST")"
    else
        cp "$backup" "$env_file" 2>/dev/null || true
        warn "matugen: generation failed — kept previous colors.env"
    fi
    rm -f "$backup"
    # Force token reload so the rest of this run renders the new palette.
    RENDER_SED_ARGS=()
}

ensure_sddm_theme() {
    # Install our own self-contained SDDM theme from sddm/theme/ into
    # /usr/share/sddm/themes/dotfiles/, rendering theme.conf.tpl from
    # the colour tokens. No third-party SDDM theme package involved.
    [[ -d "$DOTFILES_DIR/sddm/theme" ]] || return 0
    command -v sddm >/dev/null 2>&1 || { warn "sddm not installed — skipping theme"; return 0; }

    local dest=/usr/share/sddm/themes/dotfiles
    sudo rm -rf "$dest"
    sudo mkdir -p "$dest"
    sudo cp -rT "$DOTFILES_DIR/sddm/theme" "$dest"
    sudo rm -f "$dest/theme.conf.tpl"

    # Render theme.conf from colour tokens (same pipeline as everything else).
    load_color_tokens
    local rendered; rendered="$(mktemp)"
    sed "${RENDER_SED_ARGS[@]}" "$DOTFILES_DIR/sddm/theme/theme.conf.tpl" > "$rendered"
    sudo install -m 644 "$rendered" "$dest/theme.conf"
    rm -f "$rendered"

    # Blurred login background: reuse the desktop wallpaper if present.
    if [[ -f "$HOME/.config/hypr/wallpapers/default.jpg" ]]; then
        sudo install -m 644 "$HOME/.config/hypr/wallpapers/default.jpg" "$dest/background.jpg"
    fi

    sudo mkdir -p /etc/sddm.conf.d
    printf "[Theme]
Current=dotfiles
" | sudo tee /etc/sddm.conf.d/10-theme.conf >/dev/null
    sudo rm -f /etc/sddm.conf.d/10-catppuccin.conf 2>/dev/null || true

    ok "sddm: installed self-contained 'dotfiles' theme (palette from colors.env)"
}

ensure_claude_usage_conf() {
    # The waybar usage widget now queries /api/oauth/usage directly using
    # the credential the CLI maintains in ~/.claude/.credentials.json,
    # so no per-machine config is required. Kept as a no-op for legacy
    # installs that may still source the stub.
    return 0
}

ensure_default_wallpaper() {
    # Install the repo's wallpaper to ~/.config/hypr/wallpapers/default.png.
    # This single image is the theme's seed: hyprpaper shows it, SDDM
    # blurs it on the login screen, and matugen derives the whole
    # palette from it. Drop a different file in wallpapers/ + repoint
    # this to reskin the entire desktop.
    local wp_dir="$HOME/.config/hypr/wallpapers"
    mkdir -p "$wp_dir"
    local src; src="$(ls "$DOTFILES_DIR"/wallpapers/* 2>/dev/null | head -1)"
    if [[ -n "$src" ]]; then
        install -m 644 "$src" "$wp_dir/default.png"
    elif [[ ! -f "$wp_dir/default.png" ]] && command -v magick >/dev/null 2>&1; then
        magick -size 3840x2160 gradient:'#11111b-#1e1e2e' "$wp_dir/default.png"
        warn "no wallpaper in repo — generated a placeholder gradient"
    fi
}

# ── per-utility handlers ────────────────────────────────────────────
sync_dir() {
    # sync_dir <src> <dest>
    local src="$1" dest="$2"
    mkdir -p "$dest"
    cp -rT "$src" "$dest"
    render_tpl_files "$dest"
}

# Single source of truth for colours: theme/colors.env. Any file in
# the repo with a `.tpl` suffix is treated as a template — apply.sh
# renders it (replacing @TOKEN@ with the matching env value) and
# strips the `.tpl` suffix in the destination. Templates can use
# component-specific overrides inline (e.g. mix in literal alpha:
# `rgba(@BASE_R@, @BASE_G@, @BASE_B@, 0.65)`).
RENDER_SED_ARGS=()
load_color_tokens() {
    [[ ${#RENDER_SED_ARGS[@]} -gt 0 ]] && return 0  # already cached
    local env_file="$DOTFILES_DIR/theme/colors.env"
    [[ -f "$env_file" ]] || return 0
    while IFS='=' read -r key value; do
        [[ "$key" =~ ^[A-Z_][A-Z0-9_]*$ ]] || continue
        RENDER_SED_ARGS+=("-e" "s|@${key}@|${value}|g")
    done < "$env_file"
}
render_tpl_files() {
    local dest="$1"
    load_color_tokens
    [[ ${#RENDER_SED_ARGS[@]} -eq 0 ]] && return 0
    find "$dest" -name '*.tpl' -type f -print0 | while IFS= read -r -d '' tpl; do
        local rendered="${tpl%.tpl}"
        sed "${RENDER_SED_ARGS[@]}" "$tpl" > "$rendered"
        rm -f "$tpl"
    done
}

apply_hypr() {
    sync_dir "$DOTFILES_DIR/hypr" "$HOME/.config/hypr"
    chmod +x "$HOME/.config/hypr/scripts/"*.sh 2>/dev/null || true
    if pgrep -x Hyprland >/dev/null 2>&1; then
        hyprctl reload >/dev/null
        migrate_workspaces_to_rules
        ok "hypr: applied + reloaded"
    else
        ok "hypr: applied (no running session to reload)"
    fi
}

# `hyprctl reload` updates workspace rules but does NOT move existing
# workspaces to their newly-assigned monitors. Walk the resolved rules
# and dispatch moveworkspacetomonitor for each so the live session
# matches the config without a logout.
migrate_workspaces_to_rules() {
    command -v python3 >/dev/null 2>&1 || return 0
    python3 <<'PY' || true
import re, subprocess
try:
    rules = subprocess.check_output(["hyprctl", "workspacerules"], text=True, timeout=3)
except Exception:
    raise SystemExit(0)
for block in re.split(r"Workspace rule ", rules):
    block = block.strip()
    if not block:
        continue
    head, _, body = block.partition("\n")
    ws = head.split(":")[0].strip()
    m = re.search(r"monitor:\s*(\S+)", body)
    if not m:
        continue
    mon = m.group(1)
    if mon in ("<unset>", ""):
        continue
    if not (ws.isdigit() or ws.startswith("special:")):
        continue
    subprocess.run(
        ["hyprctl", "dispatch", "moveworkspacetomonitor", ws, mon],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3,
    )
PY
}

apply_hyprpaper() {
    sync_dir "$DOTFILES_DIR/hyprpaper" "$HOME/.config/hypr"  # config lives next to hyprland.conf
    # hyprpaper does NOT expand ~ or $HOME in its config — paths must be
    # absolute or it silently fails to preload (→ "Monitor has no target").
    sed -i "s|@HOME@|$HOME|g" "$HOME/.config/hypr/hyprpaper.conf"
    if pgrep -x hyprpaper >/dev/null 2>&1; then
        pkill -x hyprpaper || true
        sleep 0.2
    fi
    if pgrep -x Hyprland >/dev/null 2>&1; then
        setsid -f hyprpaper >/dev/null 2>&1 || (hyprpaper >/dev/null 2>&1 &)
        # Drive the wallpaper over IPC per-monitor (static config lines
        # race against preload — see hypr/scripts/wallpaper.sh).
        ( "$HOME/.config/hypr/scripts/wallpaper.sh" & ) 2>/dev/null || true
    fi
    ok "hyprpaper: applied"
}

apply_kitty() {
    sync_dir "$DOTFILES_DIR/kitty" "$HOME/.config/kitty"
    ok "kitty: applied"
}

apply_waybar() {
    sync_dir "$DOTFILES_DIR/waybar" "$HOME/.config/waybar"
    chmod +x "$HOME/.config/waybar/scripts/"*.{py,sh} 2>/dev/null || true
    pkill -x waybar 2>/dev/null || true
    sleep 0.3
    setsid -f waybar >/dev/null 2>&1 || (waybar >/dev/null 2>&1 &)
    ok "waybar: applied + restarted"
}

apply_mako() {
    sync_dir "$DOTFILES_DIR/mako" "$HOME/.config/mako"
    if pgrep -x mako >/dev/null 2>&1; then
        makoctl reload >/dev/null 2>&1 || { pkill -x mako; sleep 0.2; setsid -f mako >/dev/null 2>&1 || (mako >/dev/null 2>&1 &); }
    fi
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
    if command -v xsettingsd >/dev/null 2>&1; then
        pkill -x xsettingsd 2>/dev/null || true
        sleep 0.2
        setsid -f xsettingsd -c "$HOME/.config/xsettingsd/xsettingsd.conf" >/dev/null 2>&1 \
            || (xsettingsd -c "$HOME/.config/xsettingsd/xsettingsd.conf" >/dev/null 2>&1 &)
    fi
    ok "xsettingsd: applied"
}

# User-side autostart overrides — XDG spec says user files in
# ~/.config/autostart/ supersede /etc/xdg/autostart/, so these suppress
# nm-applet and blueman-applet (whose tray icons would duplicate the
# native waybar network+bluetooth modules).
apply_autostart() {
    sync_dir "$DOTFILES_DIR/autostart" "$HOME/.config/autostart"
    # Kill any instances spawned earlier in this session.
    pkill -x nm-applet 2>/dev/null || true
    pkill -f blueman-applet 2>/dev/null || true
    pkill -f blueman-tray 2>/dev/null || true
    ok "autostart: suppressed redundant tray applets"
}

# Per-app .desktop overrides + URI-scheme registrations.
# - sync any per-app .desktop overrides under applications/ (XDG spec
#   says user files in ~/.local/share/applications/ supersede
#   /usr/share/applications/);
# - register custom URL handlers (e.g. prusaslicer:// from Printables).
apply_applications() {
    if [[ -d "$DOTFILES_DIR/applications" ]]; then
        sync_dir "$DOTFILES_DIR/applications" "$HOME/.local/share/applications"
    fi

    # Pull the flatpak's exported .desktop files into the user database
    # so launchers and xdg-mime see them.
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
    fi

    # ── URL-scheme registrations ──────────────────────────────────
    # Printables "Open in PrusaSlicer" buttons emit prusaslicer:// URIs.
    # Point the handler at whichever PrusaSlicer is installed: prefer
    # the Flatpak (com.prusa3d.PrusaSlicer.desktop), fall back to the
    # packaged one (PrusaSlicer.desktop).
    if command -v xdg-mime >/dev/null 2>&1; then
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
    fi
}

# GTK + minimal Qt theming + env. GTK is the primary theme target
# (Nautilus, CopyQ's dialogs, portals); Qt apps get a Fusion-styled
# the palette via qt6ct/qt5ct so CopyQ et al. render dark.
# KDE Frameworks 6 apps stay un-themed on purpose — see packages.txt.
apply_theme() {
    sync_dir "$DOTFILES_DIR/qt6ct"          "$HOME/.config/qt6ct"
    sync_dir "$DOTFILES_DIR/qt5ct"          "$HOME/.config/qt5ct"
    sync_dir "$DOTFILES_DIR/gtk-3.0"        "$HOME/.config/gtk-3.0"
    sync_dir "$DOTFILES_DIR/gtk-4.0"        "$HOME/.config/gtk-4.0"
    sync_dir "$DOTFILES_DIR/environment.d"  "$HOME/.config/environment.d"
    sync_dir "$DOTFILES_DIR/matugen"        "$HOME/.config/matugen"
    # (matugen palette generation happens once, up front, in
    # generate_palette — gtk-{3,4}.0/colors.css is produced there.)

    # qt6ct/qt5ct's color_scheme_path field needs an absolute path —
    # its INI parser does not expand $HOME or ~. We use @HOME@ as a
    # portable placeholder and substitute it here.
    for cfg in "$HOME/.config/qt6ct/qt6ct.conf" "$HOME/.config/qt5ct/qt5ct.conf"; do
        [[ -f "$cfg" ]] && sed -i "s|@HOME@|$HOME|g" "$cfg"
    done

    # Re-read environment.d in the live systemd user manager so
    # services spawned now (e.g. xdg-portals) pick up the new env.
    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user import-environment 2>/dev/null || true

    if command -v gsettings >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.interface gtk-theme    "adw-gtk3-dark" 2>/dev/null || true
        gsettings set org.gnome.desktop.interface icon-theme   "Papirus-Dark"                            2>/dev/null || true
        gsettings set org.gnome.desktop.interface cursor-theme "Adwaita"           2>/dev/null || true
        gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"                             2>/dev/null || true
        gsettings set org.gnome.desktop.interface font-name    "Noto Sans 11"                            2>/dev/null || true
    fi
    ok "theme: GTK applied"
}

# ── run ─────────────────────────────────────────────────────────────
if (( DO_INSTALL )); then
    prime_sudo
    bootstrap_yay
    install_packages
    install_flatpaks
    ensure_zsh_login_shell
    ensure_bluetooth_service
    ensure_sddm_theme
fi

ensure_screenshot_dir
ensure_git_merge_driver
ensure_default_wallpaper
ensure_claude_usage_conf

# Regenerate the palette from the wallpaper BEFORE rendering any
# templates, so colors.env is fresh for the whole apply pass.
step "generating palette from wallpaper"
generate_palette

step "applying configs: ${TARGETS[*]}"
for util in "${TARGETS[@]}"; do
    if ! declare -f "apply_$util" >/dev/null; then
        warn "$util: no handler defined, skipping"
        continue
    fi
    # `theme` is a meta-handler that syncs multiple dirs (qt6ct/, qt5ct/,
    # gtk-3.0/, gtk-4.0/, environment.d/, kde/) — there is no top-level
    # theme/ dir. `applications` is similarly meta — it may have an
    # applications/ dir or it may just do xdg-mime registrations.
    if [[ "$util" != "theme" && "$util" != "applications" && ! -d "$DOTFILES_DIR/$util" ]]; then
        warn "$util: directory not found in repo, skipping"
        continue
    fi
    "apply_$util"
done

step "done"
