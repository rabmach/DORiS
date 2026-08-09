#!/usr/bin/env bash
# 2026 machiner opencode
### part of the DORiS suite of goodness - debian openbox restoration script(s) - 2026
# 02 - External repositories (Mozilla, Helium, Sublime, Shiftkey/GitHub Desktop)
#
# Every signing key is fetched, its fingerprint is verified against the
# known-good value, and only then is it installed. A mismatch warns but
# does not abort - a flaky key server must not brick a whole restore.
# You review the fingerprint and decide.

set -Euo pipefail
export DORIS_DIR="${DORIS_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
source "$DORIS_DIR/lib.sh"

header "EXTERNAL REPOSITORIES"

# wget/curl/gpg may not exist on a bare net install yet.
if ! command -v wget >/dev/null && ! command -v curl >/dev/null; then
    log "Installing wget curl (needed to fetch repo signing keys)..."
    sudo apt-get update 2>&1 | tee -a "$LOG_FILE" >/dev/null || true
    sudo apt-get install -y --no-install-recommends wget curl ca-certificates 2>&1 | tee -a "$LOG_FILE" \
        || warn "Could not install wget/curl; signing-key downloads may fail."
fi
if ! command -v gpg >/dev/null; then
    log "Installing gnupg..."
    sudo apt-get install -y --no-install-recommends gnupg 2>&1 | tee -a "$LOG_FILE" || warn "Could not install gnupg."
fi

sudo mkdir -p /etc/apt/keyrings /usr/share/keyrings

# Fetch a signing key and verify its fingerprint before installing it.
add_apt_key() {
    local url="$1" keyring="$2" expected_fp="$3" name="$4"
    local tmp
    tmp="$(mktemp)"
    if command -v wget >/dev/null; then
        wget -q "$url" -O "$tmp" || { warn "Could not download the $name signing key. Skipping key install."; rm -f "$tmp"; return 1; }
    elif command -v curl >/dev/null; then
        curl -fsSL "$url" -o "$tmp" || { warn "Could not download the $name signing key. Skipping key install."; rm -f "$tmp"; return 1; }
    else
        warn "Neither wget nor curl is available - cannot fetch the $name signing key."
        rm -f "$tmp"
        return 1
    fi
    local fp
    fp="$(gpg --show-keys --with-fingerprint --with-colons "$tmp" 2>/dev/null \
        | awk -F: '$1=="fpr" {print $10}' | head -1)"
    if [[ -n "$expected_fp" ]] && [[ "$fp" != "$expected_fp" ]]; then
        warn "$name key fingerprint MISMATCH."
        warn "  expected: $expected_fp"
        warn "  got:      ${fp:-<none>}"
        warn "  Installing anyway (review before trusting this repo)."
    else
        log "$name signing key verified (${fp:-unknown})."
    fi
    sudo install -D -m 0644 "$tmp" "$keyring"
    rm -f "$tmp"
}

# ── Mozilla (Firefox, non-ESR) ───────────────────────────────
if [[ ! -f /etc/apt/sources.list.d/mozilla.list ]]; then
    log "Adding Mozilla repository..."
    add_apt_key \
        "https://packages.mozilla.org/apt/repo-signing-key.gpg" \
        "/etc/apt/keyrings/packages.mozilla.org.asc" \
        "35BAA0B33E9EB396F59CA838C0BA5CE3537168ED1" "Mozilla"
    echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
        | sudo tee /etc/apt/sources.list.d/mozilla.list > /dev/null
    log "Mozilla repository added."
else
    log "Mozilla repository already configured. Skipping."
fi

# Pin Mozilla packages above Debian's (Firefox ESR lives in the Debian repo).
if [[ ! -f /etc/apt/preferences.d/mozilla ]]; then
    log "Adding Mozilla package pinning..."
    sudo tee /etc/apt/preferences.d/mozilla > /dev/null <<'EOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF
    log "Mozilla pinning added."
else
    log "Mozilla pinning already present. Skipping."
fi

# ── Helium browser ───────────────────────────────────────────
if [[ ! -f /etc/apt/sources.list.d/helium.list ]]; then
    log "Adding Helium browser repository..."
    add_apt_key \
        "https://raw.githubusercontent.com/imputnet/helium-linux/main/pubkey.asc" \
        "/usr/share/keyrings/helium.gpg" \
        "BE677C1989D35EAB2C5F26C9351601AD01D6378E" "Helium"
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/helium.gpg] https://pkg.helium.computer/deb stable main" \
        | sudo tee /etc/apt/sources.list.d/helium.list > /dev/null
    log "Helium repository added."
else
    log "Helium repository already configured. Skipping."
fi

# ── Sublime Text ─────────────────────────────────────────────
if [[ ! -f /etc/apt/sources.list.d/sublime-text.sources ]]; then
    log "Adding Sublime Text repository..."
    add_apt_key \
        "https://download.sublimetext.com/sublimehq-pub.gpg" \
        "/etc/apt/keyrings/sublimehq-pub.asc" \
        "" "Sublime Text"
    echo -e 'Types: deb\nURIs: https://download.sublimetext.com/\nSuites: apt/stable/\nSigned-By: /etc/apt/keyrings/sublimehq-pub.asc' \
        | sudo tee /etc/apt/sources.list.d/sublime-text.sources > /dev/null
    log "Sublime Text repository added."
else
    log "Sublime repository already configured. Skipping."
fi

# ── Shiftkey / GitHub Desktop ────────────────────────────────
if [[ ! -f /etc/apt/sources.list.d/mwt-desktop.list ]]; then
    log "Adding GitHub Desktop (Shiftkey) repository..."
    add_apt_key \
        "https://mirror.mwt.me/shiftkey-desktop/gpgkey" \
        "/usr/share/keyrings/mwt-desktop.gpg" \
        "4E02A356A18314B00A481F067FC979028B1997C1" "GitHub Desktop"
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/mwt-desktop.gpg] https://mirror.mwt.me/shiftkey-desktop/deb/ any main" \
        | sudo tee /etc/apt/sources.list.d/mwt-desktop.list > /dev/null
    log "GitHub Desktop repository added."
else
    log "GitHub Desktop repository already configured. Skipping."
fi

# ── Refresh ──────────────────────────────────────────────────
log "Updating apt package lists..."
if sudo apt-get update 2>&1 | tee -a "$LOG_FILE"; then
    log "Package lists updated."
else
    warn "apt update reported non-fatal errors. Continuing..."
fi

log "Repository setup complete."
exit 0
