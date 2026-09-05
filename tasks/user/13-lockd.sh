#!/usr/bin/env bash
# 2026 machiner opencode
### part of the DORiS suite of goodness - debian openbox restoration script(s) - 2026
# 13 - lockd wiring. The lockd script itself ships in DORiS bin/ (restored to
#     ~/bin by task 10); this task wires the desktop integration for the
#     current user: Thunar custom actions, the *.age mime type, the desktop
#     entries (menu launcher + double-click unlock handler) and the
#     Ctrl+Alt+E keybind. Idempotent: every step checks before it writes.
#     Key birth is NOT done here - it happens on the user's first `lockd`
#     run, so the passphrase is theirs alone.

set -Euo pipefail
export DORIS_DIR="${DORIS_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
source "$DORIS_DIR/lib.sh"

header "LOCKD - one-word encryption (age underneath)"

announce "THE LOCK" "lockd gets wired in: right-click encrypt, double-click unlock, Ctrl+Alt+E. The script proves itself before any wiring (its own selftest, hard stop on fail), and the key is never born here - it happens on your first run, so the passphrase is yours alone."
LOCKD_BIN="$CURRENT_HOME/bin/lockd"

if [[ ! -x "$LOCKD_BIN" ]]; then
    log "lockd not found at $LOCKD_BIN - skipped (task 10 restores it)"
    exit 0
fi

# ── sanity: the shipped script proves itself ────────────────
if "$LOCKD_BIN" --selftest >/dev/null 2>&1; then
    log "lockd selftest: PASS"
else
    log "WARN: lockd selftest failed - wiring skipped"
    exit 0
fi

# ── *.age mime type ─────────────────────────────────────────
MIME_DIR="$CURRENT_HOME/.local/share/mime/packages"
APP_DIR="$CURRENT_HOME/.local/share/applications"
ensure_dir "$MIME_DIR"
ensure_dir "$APP_DIR"

if [[ ! -f "$MIME_DIR/x-lockd.xml" ]]; then
    cat > "$MIME_DIR/x-lockd.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="application/x-age">
    <comment>age-encrypted file (lockd)</comment>
    <glob pattern="*.age"/>
  </mime-type>
</mime-info>
EOF
    log "mime type registered: application/x-age"
else
    log "mime type: already present"
fi

# ── desktop entries: launcher + double-click unlock handler ─
if [[ ! -f "$APP_DIR/lockd.desktop" ]]; then
    cat > "$APP_DIR/lockd.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=lockd
Comment=Encrypt files and directories - one word, password, done
Exec=$LOCKD_BIN
Icon=channel-secure
Terminal=false
Categories=Utility;Security;FileManager;
EOF
    log "desktop launcher: lockd.desktop"
else
    log "desktop launcher: already present"
fi

if [[ ! -f "$APP_DIR/lockd-decrypt.desktop" ]]; then
    cat > "$APP_DIR/lockd-decrypt.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=lockd: unlock
Comment=Decrypt an age-encrypted file with your default key
Exec=$LOCKD_BIN -d --open %f
Icon=channel-secure
Terminal=false
MimeType=application/x-age;
EOF
    log "desktop handler: lockd-decrypt.desktop (*.age double-click)"
else
    log "desktop handler: already present"
fi

# regenerate the user mime database (must be owned by the user afterwards)
if command -v update-mime-database >/dev/null; then
    update-mime-database "$CURRENT_HOME/.local/share/mime" >/dev/null 2>&1 || true
fi

# ── Thunar custom actions (encrypt / decrypt / shred) ───────
UCA="$CURRENT_HOME/.config/Thunar/uca.xml"
if [[ -f "$UCA" ]]; then
    cp -f "$UCA" "$UCA.bak-lockd" 2>/dev/null || true
    python3 - "$UCA" "$LOCKD_BIN" <<'PYEOF'
import sys
p, lockd = sys.argv[1], sys.argv[2]
s = open(p).read()
added = 0

ACTIONS = [
    ("lockd: encrypt (age)",
     f'''<action>
	<icon>channel-secure</icon>
	<name>lockd: encrypt (age)</name>
	<submenu>Scripts/Encryption</submenu>
	<command>{lockd} %F</command>
	<description>one-word encryption: password, pick, verify, wipe (or --keep)</description>
	<patterns>*</patterns>
	<directories/>
	<audio-files/>
	<image-files/>
	<other-files/>
	<text-files/>
	<video-files/>
</action>'''),
    ("lockd: decrypt",
     f'''<action>
	<icon>channel-secure</icon>
	<name>lockd: decrypt</name>
	<submenu>Scripts/Encryption</submenu>
	<command>{lockd} -d --open %F</command>
	<description>unlock .age files with the default key</description>
	<patterns>*.age</patterns>
	<other-files/>
	<text-files/>
	<video-files/>
</action>'''),
    ("lockd: shred (secure wipe)",
     f'''<action>
	<icon>edit-delete-shred</icon>
	<name>lockd: shred (secure wipe)</name>
	<command>{lockd} --shred %F</command>
	<description>secure-wipe files - gone means gone</description>
	<patterns>*</patterns>
	<directories/>
	<audio-files/>
	<image-files/>
	<other-files/>
	<text-files/>
	<video-files/>
</action>'''),
]

for name, block in ACTIONS:
    if f"<name>{name}</name>" in s:
        continue
    if "<name>Encrypt with keys</name>" in s:
        # insert before the first Encryption-family action's opening tag
        i = s.index("<action>", s.index("<name>Encrypt with keys</name>") - 400)
        s = s[:i] + block + "\n" + s[i:]
    else:
        # no Encryption family: insert before </actions>
        s = s.replace("</actions>", block + "\n</actions>", 1)
    added += 1

open(p, "w").write(s)
print(f"added: {added}")
PYEOF
    ADDED=$(python3 - "$UCA" <<'PYEOF'
import sys
print(sum(1 for _ in [l for l in open(sys.argv[1]) if "<name>lockd:" in l]))
PYEOF
)
    if xmllint --noout "$UCA" 2>/dev/null; then
        log "thunar actions: OK ($ADDED lockd entries)"
    else
        log "WARN: uca.xml broke - restoring backup"
        cp -f "$UCA.bak-lockd" "$UCA"
    fi
else
    log "no Thunar uca.xml - thunar actions skipped"
fi

# ── keybind: Ctrl+Alt+E -> quick-lock ───────────────────────
RC="$CURRENT_HOME/.config/openbox/rc.xml"
if [[ -f "$RC" ]]; then
    if grep -q 'key="C-A-e"' "$RC"; then
        log "keybind: C-A-e already bound - untouched"
    else
        cp -f "$RC" "$RC.bak-lockd" 2>/dev/null || true
        python3 - "$RC" "$LOCKD_BIN" <<'PYEOF'
import sys
p, lockd = sys.argv[1], sys.argv[2]
s = open(p).read()
block = ('    <keybind key="C-A-e">\n'
         '      <action name="Execute">\n'
         f'        <execute>{lockd}</execute>\n'
         '      </action>\n'
         '    </keybind>\n')
assert "  </keyboard>" in s, "no </keyboard> in rc.xml"
s = s.replace("  </keyboard>", block + "  </keyboard>", 1)
open(p, "w").write(s)
print("keybind inserted")
PYEOF
        if xmllint --noout "$RC" 2>/dev/null; then
            log "keybind: Ctrl+Alt+E -> lockd"
        else
            log "WARN: rc.xml broke - restoring backup"
            cp -f "$RC.bak-lockd" "$RC"
        fi
    fi
else
    log "no openbox rc.xml - keybind skipped"
fi

# ── ownership + final verify ────────────────────────────────
chown -R "$CURRENT_USER":"$CURRENT_USER" \
    "$CURRENT_HOME/.local/share/mime" \
    "$CURRENT_HOME/.local/share/applications" \
    "$CURRENT_HOME/.config/Thunar" 2>/dev/null || true
[[ -f "$RC" ]] && chown "$CURRENT_USER":"$CURRENT_USER" "$RC" 2>/dev/null || true

log "lockd ready: terminal 'lockd', right-click in Thunar, menu entry, Ctrl+Alt+E."
log "  originals are wiped after byte-verification (announced rule; --keep opts out)."
log "  your key is born on your first run - the passphrase is yours alone."
