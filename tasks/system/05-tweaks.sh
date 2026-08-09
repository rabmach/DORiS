#!/usr/bin/env bash
# 2026 machiner opencode
### part of the DORiS suite of goodness - debian openbox restoration script(s) - 2026
# 05 - System tweaks (loginfetch tty banner, Ctrl+Alt+Backspace kill-X, tty1 startx)
#
# Adapted from leomarcov's debian-openbox scripts (~/Downloads/marcov), GPL-3.0:
#   * loginfetch - dynamic /etc/issue banner (distro logo, IP, uptime, users)
#     shown on every tty login prompt via a getty ExecStartPre hook.
#   * Ctrl+Alt+Backspace kills X (XKBOPTIONS terminate:ctrl_alt_bksp).
#   * Boot to multi-user.target; tty1 autostarts X on login.
# Physlock is deliberately NOT installed - the screen-locker feature is
# not wanted. All steps are idempotent and reversible (backups in the kit).

set -Euo pipefail
export DORIS_DIR="${DORIS_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
source "$DORIS_DIR/lib.sh"

header "SYSTEM TWEAKS"

# ── 1. loginfetch: regenerate /etc/issue on every tty login ──
if [[ -f "$HARDENING/loginfetch/loginfetch" ]]; then
    write_root_file "$HARDENING/loginfetch/loginfetch" /usr/bin/loginfetch
    sudo chmod a+x /usr/bin/loginfetch
    if [[ -f "$HARDENING/loginfetch/getty-override.conf" ]]; then
        if write_root_file "$HARDENING/loginfetch/getty-override.conf" \
            /etc/systemd/system/getty@.service.d/override.conf; then
            sudo systemctl daemon-reload
        fi
    fi
    [[ -f /etc/issue.old ]] || sudo cp -a /etc/issue /etc/issue.old 2>/dev/null || true
    sudo /usr/bin/loginfetch 2>/dev/null \
        && log "  /etc/issue banner generated." \
        || warn "  loginfetch first run failed - check /usr/bin/loginfetch."
else
    warn "  hardening/loginfetch missing from the kit - skipping."
fi

# ── 2. boot to multi-user.target (login at a tty, then startx) ─
if [[ "$(systemctl get-default 2>/dev/null)" != "multi-user.target" ]]; then
    sudo systemctl set-default multi-user.target \
        && log "  default target set to multi-user.target." \
        || warn "  could not set default target."
else
    log "  default target already multi-user.target."
fi

# ── 3. tty1 autostarts X on login (idempotent, marked line) ──
CM="#DEBIAN-OPENBOX-loginfetch"
if grep -q "$CM" /etc/profile 2>/dev/null; then
    log "  tty1 startx line already in /etc/profile."
else
    backup_file /etc/profile || true
    sudo tee -a /etc/profile >/dev/null <<EOF
[ ! "\$DISPLAY" ] && [ "\$(tty)" = "/dev/tty1" ] && PROMPT_COMMAND="startx && exit;" $CM
EOF
    log "  tty1 autostart X added to /etc/profile."
fi

# ── 4. Ctrl+Alt+Backspace kills X (kill-x tweak) ──────────────
KEY=/etc/default/keyboard
if grep -q 'terminate:ctrl_alt_bksp' "$KEY" 2>/dev/null; then
    log "  Ctrl+Alt+Backspace already enabled in /etc/default/keyboard."
else
    backup_file "$KEY" || true
    if grep -q '^XKBOPTIONS=' "$KEY" 2>/dev/null; then
        sudo sed -i 's/XKBOPTIONS="/XKBOPTIONS="terminate:ctrl_alt_bksp,/' "$KEY"
    else
        echo 'XKBOPTIONS="terminate:ctrl_alt_bksp"' | sudo tee -a "$KEY" >/dev/null
    fi
    log "  Ctrl+Alt+Backspace kill-X enabled (applies on next boot)."
fi

# ── 5. notification-daemon autostart (notify-send needs it in X) ─
# Without this, notify-send (used by ~/bin/frank etc.) silently does nothing
# in a bare Openbox session. Idempotent; harmless on XFCE/GNOME autostart.
if [[ -f /usr/share/applications/notification-daemon.desktop ]]; then
    if [[ -f /etc/xdg/autostart/notification-daemon.desktop ]]; then
        log "  notification-daemon autostart already present."
    else
        backup_file /etc/xdg/autostart/notification-daemon.desktop 2>/dev/null || true
        sudo cp /usr/share/applications/notification-daemon.desktop /etc/xdg/autostart/
        sudo chmod +x /etc/xdg/autostart/notification-daemon.desktop
        log "  notification-daemon autostart installed (/etc/xdg/autostart/)."
    fi
else
    warn "  notification-daemon.desktop not found - notify-send may stay silent."
fi

log "System tweaks complete."
exit 0
