#!/usr/bin/env bash
# 2026 machiner opencode
### part of the DORiS suite of goodness - debian openbox restoration script(s) - 2026
# 06 - Verify + install marker (last system task)
#
# Confirms the important bits actually took, and records that the system
# half of DORiS has run. Rerunning the whole restore is then safe.

set -Euo pipefail
export DORIS_DIR="${DORIS_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
source "$DORIS_DIR/lib.sh"

header "VERIFICATION"

FAILS=0

check() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then
        log "  OK: $desc"
    else
        warn "  CHECK FAILED: $desc"
        FAILS=$((FAILS + 1))
    fi
}

check "firefox is installed" bash -c "command -v firefox || dpkg -s firefox >/dev/null"
check "helium-bin is installed" bash -c "command -v helium || dpkg -s helium-bin >/dev/null"
check "openbox is installed" bash -c "command -v openbox"
check "nftables is active" systemctl is-active nftables
check "auditd is active" systemctl is-active auditd
check "journald is capped" bash -c "grep -q SystemMaxUse /etc/systemd/journald.conf"
check "debsecan cron installed" test -f /etc/cron.d/debsecan

MODE="$(state_get mode)"
DNS_TARGET="$(doris_dns_server)"
if [[ "$MODE" == "direct" ]]; then
    check "stubby is active (direct mode)" systemctl is-active stubby
fi
check "DNS pinned to $DNS_TARGET" bash -c "grep -q 'nameserver $DNS_TARGET' /etc/resolv.conf"

# Icon/theme system dirs present (best-effort: skip if kit lacks assets)
if [[ -d "$ASSET_ICONS" ]]; then
    for d in "$ASSET_ICONS"/*/; do
        [[ -d "$d" ]] || continue
        check "icon theme '$(basename "$d")' system-wide" test -d "/usr/share/icons/$(basename "$d")"
    done
fi

if [[ "$FAILS" -gt 0 ]]; then
    error "Verification found $FAILS problem(s). See warnings above."
    exit 1
fi

state_set installed "$(date '+%Y-%m-%d %H:%M:%S')"
log "System restore verified and marker written ($(state_get installed))."
log "Next: reboot, then per-user setup:  ./user-setup.sh"
exit 0
