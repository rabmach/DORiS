#!/usr/bin/env bash
# 2026 machiner opencode
### part of the DORiS suite of goodness - debian openbox restoration script(s) - 2026
### selftest.sh - validate the DORiS kit before you trust a restore to it.
###
###   ./tools/selftest.sh           # full output
###   ./tools/selftest.sh --quiet   # minimal output (exit code only)
###
### Exit codes:
###   0  kit is sound
###   1  HARD failures (do not restore)
###   2  warnings only (restore, but fix when you get a chance)
###
### Checks (hard unless noted):
###   * every shell script in the kit parses (bash -n)
###   * no hardcoded login-home paths (/home/<name>) - kit must be tokenized
###   * no ~/.local/share/icons|themes references in config/ (system-wide now)
###   * every icon referenced by menu.xml exists under local/share/icons
###   * the GTK theme/icon names in settings resolve under local/share
###   * home/films.txt present, package lists parse, browsah + hardening intact
set -Euo pipefail

DORIS_DIR="${DORIS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$DORIS_DIR"

QUIET=false
[[ "${1:-}" == "--quiet" ]] && QUIET=true

HARD=0
WARN=0
say() { $QUIET || echo "$*"; }
hard() { say "  [HARD] $*"; HARD=$((HARD + 1)); }
soft() { say "  [WARN] $*"; WARN=$((WARN + 1)); }

say "== DORiS kit self-test =="

# ── 0. kit structure ─────────────────────────────────────────
for d in config bin home local/share/icons local/share/themes local/share/scripts \
         Pictures browsers hardening packages tools tasks/system tasks/user; do
    [[ -d "$d" ]] || hard "missing directory: $d"
done
[[ -f restore.sh ]] || hard "missing restore.sh"
[[ -f user-setup.sh ]] || hard "missing user-setup.sh"
[[ -f lib.sh ]] || hard "missing lib.sh"
[[ -x restore.sh ]] || soft "restore.sh not executable"
[[ -x user-setup.sh ]] || soft "user-setup.sh not executable"

# ── 1. shell syntax on every script in the kit ───────────────
# Shell scripts = .sh files or any file whose FIRST LINE is a bash/sh
# shebang (covers extensionless scripts at the top level of bin/,
# while skipping ELF binaries, python, perl, and plain data files).
while IFS= read -r -d '' f; do
    case "$f" in
        *.sh) ;;
        *) case "$(file -b --mime-type "$f" 2>/dev/null)" in
               text/*|application/x-shellscript|inode/x-empty) ;;
               *) continue ;;   # skip binaries (ELF, xcf, ...)
           esac
           case "$(head -n 1 "$f" 2>/dev/null)" in
               '#!'*bash*|'#!/'*'/sh'*) ;;
               *) continue ;;
           esac ;;
    esac
    if ! bash -n "$f" 2>/dev/null; then
        hard "syntax error in: $f"
    fi
done < <(find bin tasks tools browsers config -type f -print0 2>/dev/null)

# ── 2. no hardcoded login homes (only the $USER token) ───────
while IFS= read -r -d '' f; do
    case "$f" in
        *.png|*.jpg|*.jpeg|*.gif|*.xpm|*.svg|*.gz|*.zip|*.woff2|*.ttf|*.iso) continue ;;
    esac
    # any /home/name where name is not literally $USER
    if grep -qE '/home/[A-Za-z0-9_]+[^$]' "$f" 2>/dev/null \
       && ! grep -q '/home/\$USER' "$f" 2>/dev/null; then
        # tokenized files legitimately contain /home/$USER; flag only real names
        while IFS= read -r hit; do
            [[ "$hit" == *"/home/\$USER"* ]] && continue
            case "$hit" in *'/home/'*'$'*) continue ;; esac   # $VAR style
            hard "hardcoded home path in $f: $hit"
        done < <(grep -oE '/home/[A-Za-z0-9_]+' "$f" 2>/dev/null | sort -u)
    fi
done < <(find config home bin browsers -type f -print0 2>/dev/null)

# ── 3. config must not point at user-local icon/theme dirs ───
if grep -rqlE "local/share/icons|local/share/themes" config 2>/dev/null; then
    hard "config/ still references ~/.local/share icons/themes (system-wide now)"
fi

# ── 4. every icon referenced by menu.xml must exist in the kit ──
if [[ -f config/openbox/menu.xml ]]; then
    while IFS= read -r icon; do
        # /usr/share/icons/<name>/<path>  ->  local/share/icons/<name>/<path>
        rel="${icon#/usr/share/icons/}"
        if [[ ! -f "local/share/icons/$rel" ]]; then
            hard "menu.xml references missing icon: $icon"
        fi
    done < <(grep -oE 'icon="[^"]+"' config/openbox/menu.xml | sed -E 's/icon="([^"]+)"/\1/' | sort -u)
fi

# ── 5. GTK theme/icon names resolve in the kit ───────────────
if [[ -f config/gtk-3.0/settings.ini ]]; then
    for name in $(grep -E '^(gtk-theme-name|gtk-icon-theme-name|gtk-cursor-theme-name)=' config/gtk-3.0/settings.ini | cut -d= -f2); do
        if [[ -d "local/share/themes/$name" ]] || [[ -d "local/share/icons/$name" ]] || [[ -d "local/share/icons/default" ]]; then
            :
        else
            soft "gtk setting references '$name' not found in kit assets (may come from a package)"
        fi
    done
fi

# ── 6. films.txt (a doris staple) ────────────────────────────
[[ -f home/films.txt ]] || hard "home/films.txt missing"
[[ -s home/films.txt ]] || soft "home/films.txt is empty"

# ── 7. package lists parse ───────────────────────────────────
for list in packages/core.list packages/extras.list; do
    [[ -f "$list" ]] || { soft "missing package list: $list"; continue; }
    bad=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"
        [[ -z "$line" ]] && continue
        pkg="${line//[[:space:]]/}"
        if [[ "$pkg" =~ [^a-zA-Z0-9+._-] ]]; then
            soft "$list: weird package token: $pkg"
            bad=1
        fi
    done < "$list"
    [[ "$bad" == 0 ]] && say "  ok: $list parses"
done

# ── 8. browsah + hardening intact ────────────────────────────
[[ -f browsers/firefox/configure-firefox.sh ]] || hard "browsers/firefox/configure-firefox.sh missing"
[[ -f browsers/helium/configure-helium.sh ]] || hard "browsers/helium/configure-helium.sh missing"
[[ -f browsers/post-login.sh ]] || hard "browsers/post-login.sh missing"
[[ -f hardening/nftables/nftables.conf ]] || hard "hardening/nftables/nftables.conf missing"
[[ -f hardening/journald/journald.conf ]] || hard "hardening/journald/journald.conf missing"
[[ -f hardening/stubby/stubby.yml ]] || soft "hardening/stubby/stubby.yml missing (direct-mode DNS)"

# ── 9. bin scripts all executable-ready (checked after copy) ─
if [[ -d bin ]]; then
    while IFS= read -r -d '' f; do
        [[ -f "$f" ]] && [[ ! -x "$f" ]] && soft "bin script not executable in kit: $f"
    done < <(find bin -maxdepth 1 -type f -print0)
fi

# ── summary ──────────────────────────────────────────────────
say ""
say "  hard: $HARD   warn: $WARN"
if [[ "$HARD" -gt 0 ]]; then
    say "  -> DO NOT restore until the hard failures are fixed."
    exit 1
fi
if [[ "$WARN" -gt 0 ]]; then
    say "  -> restore-able, but the warnings are worth a look."
    exit 2
fi
say "  -> kit is sound. restore away."
exit 0
