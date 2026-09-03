#!/usr/bin/env bash
# 2026 machiner opencode
### part of the DORiS suite of goodness - debian openbox restoration script(s) - 2026
# 14 - george, installed DORMANT. The keyboard-first dashboard (urwid + tmux
#     + alacritty) is cloned and wired into ~/bin, but it does NOT start at
#     login until the user says so: ~/.xinitrc ships with the george line
#     commented out, and ~/bin/george-activate flips it on. Anyone can run
#     `george` at any time without activating anything.

set -Euo pipefail
export DORIS_DIR="${DORIS_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
source "$DORIS_DIR/lib.sh"

header "GEORGE - the keyboard-first dashboard (installed dormant)"
GEORGE_HOME="$CURRENT_HOME/george"
GEORGE_BIN="$CURRENT_HOME/bin/george"

command -v git >/dev/null || { log "git not available - george skipped"; exit 0; }
command -v alacritty >/dev/null || log "WARN: alacritty missing (in core.list) - george needs it under X"
python3 -c "import urwid" 2>/dev/null || log "WARN: python3-urwid missing (in core.list) - george cannot run"

# ── clone or refresh the repo ───────────────────────────────
if [[ -d "$GEORGE_HOME/.git" ]]; then
    log "george repo exists - refreshing (main)"
    git -C "$GEORGE_HOME" fetch origin main >/dev/null 2>&1 || true
    git -C "$GEORGE_HOME" reset -q --hard origin/main 2>/dev/null || true
else
    log "cloning rabmach/george (main)..."
    git clone -q --single-branch --branch main \
        https://github.com/rabmach/george "$GEORGE_HOME" \
        || { log "WARN: clone failed - george skipped"; exit 0; }
fi
chown -R "$CURRENT_USER":"$CURRENT_USER" "$GEORGE_HOME" 2>/dev/null || true

# ── launcher into ~/bin (task 10 already restored DORiS bin/) ─
if [[ -f "$GEORGE_HOME/bin/george" ]]; then
    cp -f "$GEORGE_HOME/bin/george" "$GEORGE_BIN"
    chmod +x "$GEORGE_BIN"
    chown "$CURRENT_USER":"$CURRENT_USER" "$GEORGE_BIN" 2>/dev/null || true
    log "launcher: $GEORGE_BIN"
else
    log "WARN: george repo has no bin/george - launcher skipped"
fi

# ── dormant by design: ~/.xinitrc ships the line commented ──
XINIT="$CURRENT_HOME/.xinitrc"
if [[ -f "$XINIT" ]] && grep -q "bin/george" "$XINIT"; then
    log "dormant state: ~/.xinitrc carries the commented george line"
    log "  activate:  ~/bin/george-activate   (starts george at every login)"
    log "  right now: run 'george' whenever you like"
else
    log "note: no george line in ~/.xinitrc - run ~/bin/george-activate after creating one"
fi

log "george installed dormant. The dashboard is one command away;"
log "  activation is a single script - never a default, never a surprise."
