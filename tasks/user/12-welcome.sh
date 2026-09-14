#!/usr/bin/env bash
# 2026 machiner opencode
### part of the DORiS suite of goodness - debian openbox restoration script(s) - 2026
# 12 - Welcome message + per-user timers (first-login niceties)
#
#   * generates ~/.config/doris/welcome.txt from the kit (tools/mkwelcome.sh)
#   * ensures ~/bin/doris-welcome is installed and autostarted once
#   * per-user welcome + timers
set -Euo pipefail
export DORIS_DIR="${DORIS_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
source "$DORIS_DIR/lib.sh"

header "WELCOME + PER-USER TIMERS"

announce "THE WELCOME MAT" "The kit writes you a welcome: the one-time credential tasks listed plain, shown once at first login, never a nag - while the security profile the system half installed stays on duty without asking you anything."

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

# ── 4. Reminder that the welcome carries credentials nags ────
log "The welcome screen lists the one-time credential tasks (pianobar,"
log "weather, keepassxc, claws-mail, filezilla)."

own_as_user "$USER_STATE_DIR" "$CURRENT_HOME/bin/doris-welcome" \
            "$CURRENT_HOME/.config/systemd/user" "$AUTOSTART"

log "Welcome + timers complete."
exit 0
