#!/usr/bin/env bash
# 2026 machiner opencode
### part of the DORiS suite of goodness - debian openbox restoration script(s) - 2026
# 11 - Stage the browsah assistant (per-user)
#
# Copies the browsah configs to ~/browsah and installs ~/bin/browsers-setup
# (the assistant). The interactive browser setup runs from the first-login
# welcome menu (task 12): it launches each browser, waits for the first run,
# applies configs, and watches the profile until the add-ons install.

set -Euo pipefail
export DORIS_DIR="${DORIS_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
source "$DORIS_DIR/lib.sh"

header "BROWSAH STAGING"

if [[ ! -d "$BROWSERS_DIR" ]] || [[ ! -f "$BROWSERS_DIR/firefox/configure-firefox.sh" ]]; then
    warn "browsers/ kit dir incomplete - skipping browsah staging."
    exit 0
fi

# ── 1. ~/browsah (only if absent - ~/browsah is the user's own repo and wins) ──
if [[ -d "$CURRENT_HOME/browsah" ]]; then
    log "~/browsah already exists - leaving it (the assistant prefers it over the kit)."
else
    ensure_dir "$CURRENT_HOME"
    cp -a "$BROWSERS_DIR" "$CURRENT_HOME/browsah"
    log "browsah configs staged at ~/browsah."
fi

# ── 2. ~/bin/browsers-setup (the assistant) ─────────────────
ensure_dir "$CURRENT_HOME/bin"
copy_if_changed "$BROWSERS_DIR/post-login.sh" "$CURRENT_HOME/bin/browsers-setup" || true
chmod +x "$CURRENT_HOME/bin/browsers-setup"
log "browsers-setup assistant installed at ~/bin/browsers-setup."

# ── 3. First-login autostart: REMOVE the old silent background watcher ──
# Browser setup is now driven interactively by doris-welcome (task 12).
# Older installs appended a background watcher line here; strip it so the
# welcome menu is the only entry point.
AUTOSTART="$CURRENT_HOME/.config/openbox/autostart"
if [[ -f "$AUTOSTART" ]] && grep -q "browsers-setup" "$AUTOSTART"; then
    backup_file "$AUTOSTART"
    sed -i '/browsers-setup/d' "$AUTOSTART"
    log "Removed the old background browsers-setup autostart line."
fi

# ── 4. Instructions ──────────────────────────────────────────
own_as_user "$CURRENT_HOME/browsah" "$CURRENT_HOME/bin/browsers-setup" "$AUTOSTART"

echo
echo "  Browser setup happens at your FIRST LOGIN into X:"
echo "    * the welcome terminal shows a menu (Firefox / Helium / both)"
echo "    * the assistant LAUNCHES each browser for you, waits for you to"
echo "      finish the first run and close it, then applies the privacy config"
echo "    * it then opens each add-on page and watches until you install it"
echo "  You can also run it manually any time:   browsers-setup"
echo "  Only the KeePassXC extension is offered for Helium."
echo

log "Browsah staging complete."
exit 0
