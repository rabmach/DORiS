#!/usr/bin/env bash
# 2026 machiner opencode
### part of the DORiS suite of goodness - debian openbox restoration script(s) - 2026
# 05 - Hardening & privacy (firewall, DNS, apparmor, logs, tweaks)
#
# DNS strategy follows /etc/doris/mode written by task 01:
#   router  -> trusted LAN router; DNS pinned to it (plaintext, local).
#   direct  -> untrusted link; stubby (DoT) listens on 127.0.0.1 and every
#              connection is pointed at it, so ALL DNS is encrypted.
#
# Everything here is reversible:
#   * /etc/nftables.conf  -> default-deny in AND out; see backup tarball
#   * systemd-resolved removed; resolv.conf managed by NetworkManager
#   * AppArmor profiles installed in COMPLAIN mode (audit only)
#   * cupsd profile disabled (stock profile breaks printing; see D15)
#   * journald capped, debsecan cron for security announcements
#   * CPU governor = powersave

set -Euo pipefail
export DORIS_DIR="${DORIS_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
source "$DORIS_DIR/lib.sh"

header "HARDENING & PRIVACY"

DNS_SERVER="$(doris_dns_server)"
MODE="$(state_get mode)"
[[ -n "$MODE" ]] || MODE="router"   # task 01 should have run; be safe
HARDENING="$HARDEN_DIR"

log "DNS mode:   $MODE"
log "DNS target: $DNS_SERVER"

# ── 1. apt: migrate all http:// sources to https:// ─────────
log "Migrating apt sources to HTTPS (if any http remain)..."
if command -v apt-get >/dev/null && grep -rqsE '^\s*deb\s+http://' /etc/apt/; then
    sudo sed -i -E 's|(^|\s)(deb(?:-src)?)\s+http://|\1\2 https://|g' \
        /etc/apt/sources.list /etc/apt/sources.list.d/*.sources 2>/dev/null || true
    log "  apt sources migrated."
else
    log "  Already using HTTPS only."
fi

# ── 2. journald caps (keep logs small, no explosion) ─────────
if [[ -f "$HARDENING/journald/journald.conf" ]]; then
    if write_root_file "$HARDENING/journald/journald.conf" /etc/systemd/journald.conf; then
        sudo systemctl restart systemd-journald
    fi
    log "  journald capped ($(grep SystemMaxUse "$HARDENING/journald/journald.conf" | head -1 | tr -s ' '))."
fi

# ── 3. /mnt/ramdisk tmpfs (browsers put their caches here) ──
if ! grep -q '/mnt/ramdisk' /etc/fstab; then
    printf 'tmpfs /mnt/ramdisk tmpfs defaults,noatime,size=3g,mode=1777 0 0\n' | sudo tee -a /etc/fstab >/dev/null
fi
sudo mkdir -p /mnt/ramdisk
if ! mountpoint -q /mnt/ramdisk; then
    sudo mount /mnt/ramdisk && log "  /mnt/ramdisk mounted (tmpfs 3g)." \
        || warn "/mnt/ramdisk mount failed - check /etc/fstab."
else
    log "  /mnt/ramdisk already mounted."
fi

# ── 4. debsecan cron (weekly CVE scan of installed packages) ─
if [[ -f "$HARDENING/cron.d/debsecan" ]]; then
    write_root_file "$HARDENING/cron.d/debsecan" /etc/cron.d/debsecan
    sudo chown root:root /etc/cron.d/debsecan
    log "  debsecan weekly cron installed."
fi

# ── 5. CPU governor = powersave (toggle script in ~/bin/gov) ─
if [[ -f "$HARDENING/systemd/cpufreq-governor.service" ]]; then
    if write_root_file "$HARDENING/systemd/cpufreq-governor.service" /etc/systemd/system/cpufreq-governor.service; then
        sudo systemctl daemon-reload
    fi
    sudo systemctl enable --now cpufreq-governor.service 2>/dev/null \
        && log "  cpufreq governor service enabled (powersave)." \
        || warn "cpufreq-governor.service failed to start - is a CPU governor driver present?"
fi

# ── 6b. sysctl drop-ins (neutral, amd64-safe) ────────────────
if compgen -G "$HARDENING/sysctl.d/60-doris-*.conf" >/dev/null; then
    for f in "$HARDENING"/sysctl.d/60-doris-*.conf; do
        name=$(basename "$f")
        write_root_file "$f" "/etc/sysctl.d/$name"
        sudo /lib/systemd/systemd-sysctl "/etc/sysctl.d/$name" 2>/dev/null \
            && log "  sysctl $name applied." \
            || warn "  sysctl $name not applied now (still applies at boot)."
    done
fi

# ── 7. AppArmor (complain mode) + auditd + review reminder ──
if [[ -d "$HARDENING/apparmor" ]]; then
    AA_CHANGED=0
    for f in helium-bin helium-bin.dist-default-allow sublime-text; do
        if [[ -f "$HARDENING/apparmor/$f" ]]; then
            write_root_file "$HARDENING/apparmor/$f" "/etc/apparmor.d/$f" && AA_CHANGED=1
        fi
    done
    if [[ "$AA_CHANGED" == "1" ]]; then
        sudo apparmor_parser -r /etc/apparmor.d/helium-bin /etc/apparmor.d/sublime-text 2>/dev/null || true
        log "  AppArmor profiles installed (complain mode)."
    else
        log "  AppArmor profiles already in place."
    fi

    # Remove stub profiles for apps that are not installed.
    # The base apparmor package ships ~90 unconfined/default_allow stubs
    # for apps that may never exist on this box. Each stub loads into the
    # kernel for zero benefit. Only touch stubs — never remove real
    # profiles (complain/enforce) or DORiS-shipped profiles.
    AA_DISABLED_DIR="/etc/backups/apparmor-disabled"
    sudo mkdir -p "$AA_DISABLED_DIR"
    AA_PRUNED=0
    DORIS_AA_PROFILES="helium-bin helium-bin.dist-default-allow sublime-text"
    for f in /etc/apparmor.d/*; do
        [[ -f "$f" ]] || continue
        bn=$(basename "$f")
        # Skip DORiS-shipped profiles, abstractions, tunables, ABI, local includes
        [[ "$bn" == abi || "$bn" == abstractions || "$bn" == tunables \
            || "$bn" == local || "$bn" == disable || "$bn" == force-complain \
            || "$bn" == *".d" ]] && continue
        echo "$DORIS_AA_PROFILES" | grep -qw "$bn" && continue
        # Only touch unconfined or default_allow stubs
        grep -qE "flags=\((unconfined|default_allow)\)" "$f" || continue
        # Extract binary path from profile line
        bin_path=$(grep -oE 'profile [^ ]+ "?(/[^ "]+"?)' "$f" | grep -oE '/[^ "]+')
        [[ -z "$bin_path" ]] && continue
        # If binary exists on disk, skip — app is installed
        [[ -f "$bin_path" ]] && continue
        # Binary not found — prune the stub
        sudo mv "$f" "$AA_DISABLED_DIR/" && AA_PRUNED=$((AA_PRUNED + 1))
    done
    if [[ "$AA_PRUNED" -gt 0 ]]; then
        sudo aa-teardown 2>/dev/null || true
        sudo /lib/apparmor/apparmor.systemd reload 2>/dev/null || true
        log "  AppArmor: pruned $AA_PRUNED stub profiles for uninstalled apps."
    fi

    # Disable the stock cupsd profile. The cups-daemon package ships an
    # AppArmor profile that is fundamentally incomplete — it blocks every
    # filter, backend, CGI script, font path, and capability CUPS needs.
    # Fixing it is whack-a-mole (gs, poppler, fontconfig, PAM, audit_write,
    # setgid/setuid/dac_read_search/fsetid/kill capabilities, CGI binaries…).
    # CUPS listens on localhost:631 only and the firewall already controls
    # egress — the profile is not worth the maintenance tax.
    if [[ -f /etc/apparmor.d/usr.sbin.cupsd ]] && ! [[ -L /etc/apparmor.d/disable/usr.sbin.cupsd ]]; then
        sudo aa-disable /usr/sbin/cupsd 2>/dev/null || true
        log "  AppArmor: cupsd profile disabled (see decision journal D15)."
    fi

    # auditd must be running for complain-mode profiles to log anywhere.
    if command -v auditd >/dev/null; then
        if [[ -f "$HARDENING/auditd/auditd.conf" ]]; then
            write_root_file "$HARDENING/auditd/auditd.conf" /etc/audit/auditd.conf
        fi
        sudo systemctl enable --now auditd.service 2>/dev/null \
            && log "  auditd active (AppArmor denials land in /var/log/audit/audit.log)." \
            || warn "auditd failed to start."
    fi

    # The weekly review reminder is a per-user systemd user timer; it is
    # installed by user-setup.sh (task 12), not here.
fi

# ── 8. DNS ───────────────────────────────────────────────────
log "Configuring DNS (mode=$MODE, target=$DNS_SERVER)..."
NM_CHANGED=0
sudo mkdir -p /etc/NetworkManager/conf.d

# systemd-resolved off everywhere - NetworkManager owns resolv.conf.
if ! grep -q '^dns=default' /etc/NetworkManager/conf.d/dns.conf 2>/dev/null; then
    printf '[main]\ndns=default\n' | sudo tee /etc/NetworkManager/conf.d/dns.conf >/dev/null
    NM_CHANGED=1
fi
if systemctl is-active systemd-resolved.service >/dev/null 2>&1; then
    sudo systemctl stop systemd-resolved.service
    NM_CHANGED=1
fi
sudo systemctl mask systemd-resolved.service systemd-resolved.socket 2>/dev/null || true
if dpkg -l systemd-resolved 2>/dev/null | grep -q '^ii'; then
    sudo apt-get purge -y -q systemd-resolved libnss-resolve >/dev/null 2>&1 || true
    NM_CHANGED=1
fi
if [[ -L /etc/resolv.conf ]]; then
    sudo rm -f /etc/resolv.conf
    NM_CHANGED=1
fi

# Direct (untrusted) link: encrypted DNS for EVERYTHING via stubby/DoT.
if [[ "$MODE" == "direct" ]]; then
    log "  direct mode: installing stubby (DoT) and pinning DNS to 127.0.0.1..."
    apt_install stubby || warn "  stubby install failed - DNS will not be encrypted!"

    STUBBY_CONF="/etc/stubby/stubby.yml"
    if [[ -f "$HARDENING/stubby/stubby.yml" ]]; then
        if write_root_file "$HARDENING/stubby/stubby.yml" "$STUBBY_CONF"; then
            sudo systemctl restart stubby 2>/dev/null || true
        fi
    fi
    sudo systemctl enable --now stubby 2>/dev/null \
        && log "  stubby active (DoT to Cloudflare + Quad9 on 127.0.0.1:53)." \
        || warn "  stubby failed to start."

    # Point every non-guest connection at the local stub.
    while IFS= read -r conn; do
        [[ -z "$conn" ]] && continue
        case "$conn" in *[Gg]uest*) log "  Skipping guest profile: $conn"; continue ;; esac
        cur=$(nmcli -t -f ipv4.dns,ipv4.ignore-auto-dns,ipv6.ignore-auto-dns connection show "$conn" 2>/dev/null || true)
        if [[ "$cur" == *"127.0.0.1"* && "$cur" == *"ipv4.ignore-auto-dns:yes"* ]]; then
            log "  $conn already uses stubby DNS - skipped."
            continue
        fi
        sudo nmcli connection modify "$conn" ipv4.dns 127.0.0.1 ipv4.ignore-auto-dns yes ipv6.ignore-auto-dns yes 2>/dev/null \
            && { log "  $conn -> stubby (127.0.0.1)"; NM_CHANGED=1; }
    done < <(nmcli -t -f NAME connection show 2>/dev/null || true)
else
    # Trusted LAN: pin to the router.
    if grep -qE '^iface (en[^ ]*|wl[^ ]*) inet (dhcp|static)' /etc/network/interfaces 2>/dev/null; then
        log "  ifupdown-managed NIC detected - migrating to NetworkManager..."
        sudo cp -a /etc/network/interfaces /etc/network/interfaces.doris-bak 2>/dev/null || true
        nic=$(grep -E '^iface (en[^ ]*|wl[^ ]*) inet' /etc/network/interfaces.doris-bak | head -1 | awk '{print $2}')
        grep -vE '^(allow-hotplug|auto|iface) ' /etc/network/interfaces \
            | sudo tee /etc/network/interfaces >/dev/null
        printf 'auto lo\niface lo inet loopback\n' | sudo tee -a /etc/network/interfaces >/dev/null
        if [[ -n "$nic" ]] && ! nmcli -t connection show 2>/dev/null | grep -qi "$nic"; then
            sudo nmcli con add type ethernet ifname "$nic" con-name "Wired" \
                ipv4.method auto ipv4.dns "$DNS_SERVER" ipv4.ignore-auto-dns yes \
                ipv6.method auto ipv6.ignore-auto-dns yes >/dev/null 2>&1 \
                && log "  NM profile 'Wired' created for $nic (DNS $DNS_SERVER)"
        fi
        NM_CHANGED=1
    fi
    sudo apt-get purge -y -q ifupdown dhcpcd-base 2>/dev/null || true

    # Pin non-guest NetworkManager connections to the trusted router DNS.
    while IFS= read -r conn; do
        [[ -z "$conn" ]] && continue
        case "$conn" in *[Gg]uest*) log "  Skipping guest profile: $conn"; continue ;; esac
        cur=$(nmcli -t -f ipv4.dns,ipv4.ignore-auto-dns,ipv6.ignore-auto-dns connection show "$conn" 2>/dev/null || true)
        if [[ "$cur" == *"$DNS_SERVER"* && "$cur" == *"ipv4.ignore-auto-dns:yes"* \
              && "$cur" == *"ipv6.ignore-auto-dns:yes"* ]]; then
            log "  $conn already uses DNS $DNS_SERVER - skipped."
            continue
        fi
        sudo nmcli connection modify "$conn" ipv4.dns "$DNS_SERVER" ipv4.ignore-auto-dns yes ipv6.ignore-auto-dns yes 2>/dev/null \
            && { log "  $conn -> DNS $DNS_SERVER"; NM_CHANGED=1; }
    done < <(nmcli -t -f NAME connection show 2>/dev/null || true)
fi

if [[ "$NM_CHANGED" == "1" ]]; then
    sudo systemctl restart NetworkManager
    sleep 3
else
    log "  NetworkManager config unchanged - not restarting."
fi

# Enable any wifi radio (base installs often leave it rfkill-blocked).
if nmcli -t device 2>/dev/null | grep -qiE ':wifi:'; then
    sudo nmcli radio wifi on 2>/dev/null || true
    log "  wifi radio enabled for $(nmcli -t device | awk -F: '$2=="wifi" {print $1; exit}')."
fi

log "  resolv.conf: $(grep nameserver /etc/resolv.conf 2>/dev/null | tr '\n' ' ')"
if ! grep -q "nameserver $DNS_SERVER" /etc/resolv.conf; then
    warn "Expected nameserver $DNS_SERVER in resolv.conf but it is not there."
    warn "Check the NetworkManager connections (nmcli con show) and rerun task 05."
fi

# ── 9. nftables default-deny firewall (the lock-down; do last) ─
if [[ -f "$HARDENING/nftables/nftables.conf" ]]; then
    NFT_CHANGED=0
    write_root_file "$HARDENING/nftables/nftables.conf" /etc/nftables.conf && NFT_CHANGED=1
    if [[ -f "$HARDENING/modules-load.d/ftp-helper.conf" ]]; then
        write_root_file "$HARDENING/modules-load.d/ftp-helper.conf" /etc/modules-load.d/ftp-helper.conf
        sudo modprobe nf_conntrack_ftp 2>/dev/null || true
    fi
    sudo systemctl enable nftables.service
    if [[ "$NFT_CHANGED" == "1" ]] || ! systemctl is-active --quiet nftables.service; then
        sudo systemctl restart nftables.service 2>/dev/null \
            && log "  nftables active: default-deny inbound + outbound." \
            || warn "  nftables failed to load - run: sudo nft -f /etc/nftables.conf (see log)."
    else
        log "  nftables already active with the same ruleset."
    fi
fi

log "Hardening complete. Reboot recommended."
exit 0
