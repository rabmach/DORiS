#!/usr/bin/env bash
# 2026 machiner opencode
### part of the DORiS suite of goodness - debian openbox restoration script(s) - 2026
# 03 - Core packages (the big apt pass) + optional extras
#

set -Euo pipefail
export DORIS_DIR="${DORIS_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
source "$DORIS_DIR/lib.sh"

header "PACKAGE INSTALLATION"

CORE_LIST="$DORIS_DIR/packages/core.list"
[[ -f "$CORE_LIST" ]] || die "packages/core.list not found."

mapfile -t PACKAGES < <(grep -vE '^\s*(#|$)' "$CORE_LIST")
log "Core packages to install: ${#PACKAGES[@]}"

# ── Vendor-specific firmware/drivers ─────────────────────────
if is_intel; then
    log "Intel CPU detected - adding intel-microcode + Intel VA-API drivers."
    PACKAGES+=(intel-microcode intel-media-va-driver-non-free i965-va-driver)
elif is_amd; then
    log "AMD CPU detected - adding amd64-microcode."
    PACKAGES+=(amd64-microcode)
else
    warn "Unknown CPU vendor; skipping microcode packages."
fi

# ── Optional extras (--extras / DORIS_EXTRAS=1) ──────────────
if [[ "${EXTRAS:-0}" == "1" ]] && [[ -f "$DORIS_DIR/packages/extras.list" ]]; then
    mapfile -t EXTRA_PKGS < <(grep -vE '^\s*(#|$)' "$DORIS_DIR/packages/extras.list")
    log "Extras requested: ${#EXTRA_PKGS[@]} additional packages."
    PACKAGES+=( "${EXTRA_PKGS[@]}" )
fi

log "This may take a while. Download size is several gigabytes."

NEEDED=0
for pkg in "${PACKAGES[@]}"; do
    is_installed "$pkg" || NEEDED=1
done

if [[ "$NEEDED" == "0" ]]; then
    log "All core packages already installed - nothing to do."
else
    if apt_install "${PACKAGES[@]}"; then
        log "Core packages installed."
    else
        warn "Some core packages failed to install (see log)."
    fi
    # Capture the microcode/initramfs state only when we changed the package set.
    sudo update-initramfs -u -k all >/dev/null 2>&1 || true
fi

INSTALLED=$(dpkg -l 2>/dev/null | grep -c '^ii')
log "Total installed packages: $INSTALLED"

exit 0
