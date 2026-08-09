#!/usr/bin/env bash
# 2026 machiner opencode
### part of the DORiS suite of goodness - debian openbox restoration script(s) - 2026
# 00 - Prerequisites (root, networking, wayland, kit sanity, self-test)
#
# Hard failures (die): no root, no networking, kit self-test errors,
#                       missing kit assets.
# Soft (warn):          wayland session present, low disk space.

set -Euo pipefail
export DORIS_DIR="${DORIS_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
source "$DORIS_DIR/lib.sh"

header "PREREQUISITES"

# ── 1. Must run as root ─────────────────────────────────────
if [[ "$(id -u)" -ne 0 ]]; then
    die "System restore must run as root:  sudo ./restore.sh"
fi
log "Running as root."

# ── 2. amd64 target ─────────────────────────────────────────
case "$(uname -m)" in
    x86_64|amd64) log "Architecture: amd64 - supported." ;;
    *) warn "Architecture $(uname -m) - DORiS targets amd64; firmware/driver lists may not fit." ;;
esac

# ── 3. Networking is a hard requirement ─────────────────────
require_network

# ── 4. Disk space sanity (package install + asset copy) ──────
ROOT_FREE=$(df -Pk / | awk 'NR==2 {print $4}')
if [[ -n "$ROOT_FREE" ]] && (( ROOT_FREE < 4 * 1024 * 1024 )); then
    warn "Low disk space on / (${ROOT_FREE} KiB free). A full restore needs ~5 GiB+."
fi

# ── 5. Wayland session detected? warn, stay X11 ─────────────
if [[ "$(wayland_present)" == "yes" ]]; then
    warn "A Wayland session/desktop is installed on this machine."
    warn "DORiS builds an X11/openbox desktop and does NOT configure Wayland."
    warn "After the first reboot log in with 'Xsession' (or run 'startx');"
    warn "a Wayland-only login will not show the doris desktop."
else
    log "No Wayland session detected - X11/openbox path is correct."
fi

# ── 6. Kit sanity + self-test ───────────────────────────────
[[ -f "$DORIS_DIR/packages/core.list" ]] || die "packages/core.list missing from the kit."
[[ -f "$DORIS_DIR/config/openbox/rc.xml" ]] || die "config/openbox/rc.xml missing from the kit."
[[ -f "$DORIS_DIR/home/films.txt" ]] || warn "home/films.txt missing - the films.txt restore is a doris staple."

if [[ -x "$DORIS_DIR/tools/selftest.sh" ]]; then
    log "Running kit self-test (tools/selftest.sh)..."
    if "$DORIS_DIR/tools/selftest.sh" --quiet; then
        log "Self-test passed."
    else
        rc=$?
        if [[ $rc -eq 2 ]]; then
            warn "Self-test reported warnings only - continuing."
        else
            die "Kit self-test FAILED (exit $rc). Fix the kit before restoring."
        fi
    fi
else
    warn "tools/selftest.sh not present - skipping kit self-test."
fi

log "Prerequisites OK."
exit 0
