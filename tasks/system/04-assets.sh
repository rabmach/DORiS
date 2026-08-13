#!/usr/bin/env bash
# 2026 machiner opencode
### part of the DORiS suite of goodness - debian openbox restoration script(s) - 2026
# 04 - System-wide icons + themes (vendored local assets, no network needed)
#
# Everything lands in /usr/share so root-owned apps (synaptic, thunar as
# root, package managers) get the same look. Nothing is installed under
# ~/.local/share/icons or ~/.local/share/themes - the kit and menu.xml
# point exclusively at system paths. Check-then-skip keeps this safe to
# rerun on a machine that already has the assets.

set -Euo pipefail
export DORIS_DIR="${DORIS_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
source "$DORIS_DIR/lib.sh"

header "SYSTEM-WIDE ICONS + THEMES"

if [[ ! -d "$ASSET_ICONS" ]] && [[ ! -d "$ASSET_THEMES" ]]; then
    warn "No local theme/icon assets found. Skipping."
    exit 0
fi

INSTALLED_ANY=0

# ── Icon themes -> /usr/share/icons ──────────────────────────
if [[ -d "$ASSET_ICONS" ]]; then
    for icon_dir in "$ASSET_ICONS"/*/; do
        [[ -d "$icon_dir" ]] || continue
        name=$(basename "$icon_dir")
        target="/usr/share/icons/$name"
        if [[ -d "$target" ]]; then
            log "Icon theme '$name' already at $target - skipped."
            continue
        fi
        log "Installing icon theme '$name' -> $target ..."
        sudo cp -R "$icon_dir" "$target"
        INSTALLED_ANY=1
    done
fi

# ── Window/GTK themes -> /usr/share/themes ──────────────────
if [[ -d "$ASSET_THEMES" ]]; then
    for theme_dir in "$ASSET_THEMES"/*/; do
        [[ -d "$theme_dir" ]] || continue
        name=$(basename "$theme_dir")
        target="/usr/share/themes/$name"
        if [[ -d "$target" ]]; then
            log "Theme '$name' already at $target - skipped."
            continue
        fi
        log "Installing theme '$name' -> $target ..."
        sudo cp -R "$theme_dir" "$target"
        INSTALLED_ANY=1
    done
fi

# ── Refresh icon caches only if we installed something ──────
if [[ "$INSTALLED_ANY" == "1" ]] && command -v gtk-update-icon-cache &>/dev/null; then
    log "Refreshing icon caches..."
    sudo find /usr/share/icons -maxdepth 1 -mindepth 1 -type d \
        -exec gtk-update-icon-cache -q -f {} \; 2>/dev/null || true
fi

# ── Sanity: menu.xml + GTK must reference only system paths ─
if grep -rqlE "local/share/icons|local/share/themes" "$DORIS_DIR/config" 2>/dev/null; then
    warn "config/ still references ~/.local/share icons/themes."
    warn "Run: grep -rlE 'local/share/icons|local/share/themes' $DORIS_DIR/config"
else
    log "All config icon/theme references point at system paths."
fi

# ── File-manager default (x-file-manager -> thunar) ─────────
# BUG-007: this used to live in the per-user half as `sudo update-alternatives
# --set`, but a plain ./user-setup.sh has no business needing root, and sudo
# on a fresh install prompts for a password - so the win+f tweak silently
# never applied there. The system-wide alternative belongs to the SYSTEM
# half (we are root here); the per-user half only sets the inode/directory
# handler for the individual user.
if command -v thunar >/dev/null 2>&1; then
    if sudo update-alternatives --set x-file-manager /usr/bin/thunar 2>/dev/null; then
        log "x-file-manager alternative set -> thunar."
    else
        warn "update-alternatives x-file-manager failed (is thunar installed?)."
    fi
else
    log "thunar not installed - x-file-manager alternative left as-is."
fi

log "Icons/themes installed system-wide."
exit 0
