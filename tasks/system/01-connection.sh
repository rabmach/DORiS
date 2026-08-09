#!/usr/bin/env bash
# 2026 machiner opencode
### part of the DORiS suite of goodness - debian openbox restoration script(s) - 2026
# 01 - Connection / DNS-strategy detection
#
# Decides which of the two security postures applies and records it in
# /etc/doris/mode (+ /etc/doris/router-ip for the trusted-LAN case).
#
#   router  = default gateway is RFC1918/link-local/ULA  -> that router is
#             trusted; DNS is pinned to it (task 05).
#   direct  = public/CGNAT gateway (cable straight into the ISP's router)
#             -> the connection is NOT trusted; encrypted DNS is forced
#             (stubby/DoT via 127.0.0.1) by task 05.
#   unknown = no default route found -> assume the worst (direct) and warn.

set -Euo pipefail
export DORIS_DIR="${DORIS_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
source "$DORIS_DIR/lib.sh"

header "CONNECTION / DNS STRATEGY"

MODE="$(detect_connection)"
GW="$(detect_gateway)"

log "Default gateway: ${GW:-<none>}"
log "Detected mode:   $MODE"

case "$MODE" in
    router)
        state_set mode router
        state_set router-ip "$GW"
        log "Trusted LAN behind a router - DNS will be pinned to $GW."
        info "If you later move this machine onto a direct/untrusted link,"
        info "rerun:  sudo ./restore.sh --only 05   (switches DNS to DoT)."
        ;;
    direct)
        state_set mode direct
        info "DIRECT ISP LINK DETECTED - this connection is not trusted."
        info "Encrypted DNS (stubby/DoT via 127.0.0.1) will be forced in task 05."
        ;;
    unknown)
        state_set mode direct
        warn "Could not determine a default gateway."
        warn "Treating the connection as untrusted (encrypted DNS)."
        warn "If this machine is actually on a trusted LAN, set:"
        warn "  sudo sh -c 'echo router > /etc/doris/mode'   before rerunning task 05."
        ;;
esac

log "Connection strategy recorded."
exit 0
