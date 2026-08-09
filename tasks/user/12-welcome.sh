#!/usr/bin/env bash
# 2026 machiner opencode
### part of the DORiS suite of goodness - debian openbox restoration script(s) - 2026
# 12 - Welcome message + per-user timers (first-login niceties)
#
#   * generates ~/.config/doris/welcome.txt from the kit (tools/mkwelcome.sh)
#   * ensures ~/bin/doris-welcome is installed and autostarted once
#   * arms the per-user AppArmor review reminder timer
set -Euo pipefail
export DORIS_DIR="${DORIS_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
source "$DORIS_DIR/lib.sh"

header "WELCOME + PER-USER TIMERS"

USER_STATE_DIR="$DORIS_USER_STATE"
ensure_dir "$USER_STATE_DIR"

# ── 1. Generate the welcome text from the kit ────────────────
if [[ -x "$DORIS_DIR/tools/mkwelcome.sh" ]]; then
    "$DORIS_DIR/tools/mkwelcome.sh" > "$USER_STATE_DIR/welcome.txt" 2>>"$ERROR_FILE" \
        && log "Welcome text generated ($USER_STATE_DIR/welcome.txt, $(wc -l < "$USER_STATE_DIR/welcome.txt") lines)." \
        || warn "Welcome generation had problems."
else
    warn "tools/mkwelcome.sh missing - no welcome text generated."
fi

# ── 2. Install the welcome runner into ~/bin ────────────────
if [[ -f "$DORIS_DIR/bin/doris-welcome" ]]; then
    ensure_dir "$CURRENT_HOME/bin"
    copy_if_changed "$DORIS_DIR/bin/doris-welcome" "$CURRENT_HOME/bin/doris-welcome" || true
    chmod +x "$CURRENT_HOME/bin/doris-welcome"
    log "doris-welcome installed at ~/bin/doris-welcome."
fi

# ── 3. First-login autostart (once per user) ─────────────────
AUTOSTART="$CURRENT_HOME/.config/openbox/autostart"
if [[ -f "$AUTOSTART" ]] && ! grep -q "doris-welcome" "$AUTOSTART"; then
    backup_file "$AUTOSTART"
    cat >> "$AUTOSTART" <<EOF

# doris first-login welcome (shows once, then self-disables).
(sleep 10s && exec \$HOME/bin/doris-welcome) &
EOF
    log "Welcome autostart entry added."
fi

# ── 4. Per-user AppArmor review reminder timer ───────────────
# During a root-run user-setup there is usually no user bus yet, so we
# install the units now and arm the timer on the first login instead
# (systemctl enable is idempotent, so the autostart line is harmless).
if [[ -f "$HARDEN_DIR/systemd/apparmor-review-reminder.service" ]] \
   && [[ -f "$HARDEN_DIR/systemd/apparmor-review-reminder.timer" ]]; then
    UDIR="$CURRENT_HOME/.config/systemd/user"
    ensure_dir "$UDIR"
    copy_if_changed "$HARDEN_DIR/systemd/apparmor-review-reminder.service" \
        "$UDIR/apparmor-review-reminder.service" || true
    copy_if_changed "$HARDEN_DIR/systemd/apparmor-review-reminder.timer" \
        "$UDIR/apparmor-review-reminder.timer" || true
    chmod +x "$UDIR/apparmor-review-reminder.service" 2>/dev/null || true

    if systemctl --user is-system-running >/dev/null 2>&1 \
       || [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user enable --now apparmor-review-reminder.timer 2>/dev/null \
            && log "AppArmor review reminder timer armed for $CURRENT_USER." \
            || warn "Could not arm the AppArmor review timer now - will retry at login."
    else
        log "No user bus yet (fresh restore) - the timer is armed at first login."
    fi

    # Arm it at first login regardless.
    AUTOSTART="$CURRENT_HOME/.config/openbox/autostart"
    if [[ -f "$AUTOSTART" ]] && ! grep -q "apparmor-review-reminder" "$AUTOSTART"; then
        backup_file "$AUTOSTART"
        cat >> "$AUTOSTART" <<EOF

# arm the AppArmor review reminder (idempotent; needs a login session).
systemctl --user enable --now apparmor-review-reminder.timer 2>/dev/null || true
EOF
        log "Timer auto-arm added to openbox autostart."
    fi
fi

# ── 5. Reminder that the welcome carries credentials nags ────
log "The welcome screen lists the one-time credential tasks (pianobar,"
log "weather, keepassxc, claws-mail, filezilla, github-desktop)."

own_as_user "$USER_STATE_DIR" "$CURRENT_HOME/bin/doris-welcome" \
            "$CURRENT_HOME/.config/systemd/user" "$AUTOSTART"

log "Welcome + timers complete."
exit 0
