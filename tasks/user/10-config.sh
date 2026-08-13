#!/usr/bin/env bash
# 2026 machiner opencode
### part of the DORiS suite of goodness - debian openbox restoration script(s) - 2026
# 10 - Per-user config restoration (dotfiles, app configs, ~/bin, films.txt,
#      Thunar scripts, wallpapers). Idempotent: existing files are backed up
#      first, so running this for a second user on the same box is safe.

set -Euo pipefail
export DORIS_DIR="${DORIS_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
source "$DORIS_DIR/lib.sh"

header "PER-USER CONFIGURATION RESTORATION"
log "Restoring for $CURRENT_USER ($CURRENT_HOME)"

# ── ~/.config/ ──────────────────────────────────────────────
if [[ -d "$DORIS_DIR/config" ]]; then
    log "Restoring ~/.config/ from doris/config/..."
    ensure_dir "$CURRENT_HOME/.config"
    for item in "$DORIS_DIR/config/"*; do
        [[ -e "$item" ]] || continue
        name=$(basename "$item")
        target="$CURRENT_HOME/.config/$name"
        if [[ -d "$item" ]]; then
            backup_and_copy_dir "$item" "$target"
        else
            backup_and_copy "$item" "$target"
        fi
    done

    # Bake in $USER / $HOSTNAME tokens across all non-executable text configs.
    log "Replacing \$USER / \$HOSTNAME tokens in config files..."
    apply_tokens_tree "$CURRENT_HOME/.config"

    # openbox autostart must be executable or nothing starts at login.
    if [[ -f "$CURRENT_HOME/.config/openbox/autostart" ]]; then
        chmod +x "$CURRENT_HOME/.config/openbox/autostart" 2>/dev/null || true
    fi
fi

# ── ~/bin/ ──────────────────────────────────────────────────
if [[ -d "$DORIS_DIR/bin" ]]; then
    log "Restoring ~/bin/ from doris/bin/..."
    ensure_dir "$CURRENT_HOME/bin"
    for item in "$DORIS_DIR/bin/"*; do
        [[ -e "$item" ]] || continue
        backup_and_copy "$item" "$CURRENT_HOME/bin/$(basename "$item")"
    done
    chmod -R +x "$CURRENT_HOME/bin/"
    log "  Made ~/bin/ executable."
fi

# ── ~/.local/share/scripts/ (Thunar custom-action scripts) ──
if [[ -d "$ASSET_SCRIPTS" ]]; then
    log "Restoring ~/.local/share/scripts/ ..."
    ensure_dir "$CURRENT_HOME/.local/share"
    for item in "$ASSET_SCRIPTS/"*; do
        [[ -e "$item" ]] || continue
        backup_and_copy_dir "$item" "$CURRENT_HOME/.local/share/scripts/$(basename "$item")"
    done
    chmod -R +x "$CURRENT_HOME/.local/share/scripts/"
    log "  Made ~/.local/share/scripts/ executable."
fi

# ── Hidden dotfiles + regular home files from home/ ─────────
if [[ -d "$DORIS_DIR/home" ]]; then
    log "Restoring files from doris/home/ (dotfiles, films.txt, xinitrc)..."
    ensure_dir "$CURRENT_HOME"
    for item in "$DORIS_DIR/home/".* "$DORIS_DIR/home/"*; do
        name=$(basename "$item")
        case "$name" in .|..) continue ;; esac
        [[ -e "$item" ]] || continue
        if [[ -d "$item" ]]; then
            backup_and_copy_dir "$item" "$CURRENT_HOME/$name"
        else
            backup_and_copy "$item" "$CURRENT_HOME/$name"
        fi
    done
    log "  Home files restored."
fi

# films.txt is a doris staple and easy to forget - make sure it is there.
if [[ -f "$CURRENT_HOME/films.txt" ]]; then
    log "  ~/films.txt present ($(wc -l < "$CURRENT_HOME/films.txt") lines)."
else
    warn "  ~/films.txt missing after restore - copy it from the kit:"
    warn "    cp $DORIS_DIR/home/films.txt ~/films.txt"
fi

# ── Pictures/ (wallpapers) ──────────────────────────────────
if [[ -d "$DORIS_DIR/Pictures" ]]; then
    log "Restoring Pictures/ ..."
    ensure_dir "$CURRENT_HOME/Pictures"
    for item in "$DORIS_DIR/Pictures/"*; do
        [[ -e "$item" ]] || continue
        name=$(basename "$item")
        if [[ -d "$item" ]]; then
            backup_and_copy_dir "$item" "$CURRENT_HOME/Pictures/$name"
        else
            backup_and_copy "$item" "$CURRENT_HOME/Pictures/$name"
        fi
    done
fi

# ── Create XDG user dirs (first run only) ───────────────────
command -v xdg-user-dirs-update &>/dev/null && xdg-user-dirs-update 2>/dev/null || true

# ── File-manager default (thunar owns x-file-manager + inode/directory) ─
# BUG-007: the SYSTEM-wide x-file-manager alternative is set by task 04
# (root). Here we only set the per-user inode/directory handler - no sudo, so
# a plain ./user-setup.sh works without a password prompt. Failures log.
if command -v thunar >/dev/null 2>&1; then
    if [[ "$(id -u)" -eq 0 ]]; then
        runuser -u "$CURRENT_USER" -- xdg-mime default thunar.desktop \
            inode/directory 2>/dev/null \
            || warn "  xdg-mime default failed for $CURRENT_USER (non-fatal)."
    else
        xdg-mime default thunar.desktop inode/directory 2>/dev/null \
            || warn "  xdg-mime default failed (non-fatal)."
    fi
    log "  inode/directory handler set to thunar for $CURRENT_USER."
else
    warn "  thunar not found - skipping file-manager default."
fi

# ── Keep everything user-owned even when run via sudo ───────
own_as_user "$CURRENT_HOME/.config" "$CURRENT_HOME/bin" \
            "$CURRENT_HOME/.local/share/scripts" "$CURRENT_HOME/Pictures" \
            "$CURRENT_HOME/films.txt" "$CURRENT_HOME/.xinitrc" \
            "$CURRENT_HOME/.bashrc" "$CURRENT_HOME/.bash_aliases" \
            "$CURRENT_HOME/.bash_functions" "$CURRENT_HOME/.bashcolors" \
            "$CURRENT_HOME/.profile" "$CURRENT_HOME/.gtkrc-2.0"

# ── Zip backups ─────────────────────────────────────────────
zip_backups

log "Per-user configuration restoration complete."
exit 0
