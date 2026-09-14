#!/usr/bin/env bash
# 2026 machiner opencode
### part of the DORiS suite of goodness - debian openbox restoration script(s) - 2026
# 05 - Hardening & privacy (firewall, DNS, logs, tweaks)
#
# DNS strategy follows /etc/doris/mode written by task 01:
#   router  -> trusted LAN router; DNS pinned to it (plaintext, local).
#   direct  -> untrusted link; DNS rides DHCP (plaintext). The old stubby
#              (DoT) layer is retired - encryption is the router's or the
#              browser's job now (NextDNS DoH), not a laptop daemon's.
#
# Everything here is reversible:
#   * /etc/nftables.conf  -> default-deny in AND out; see backup tarball
#   * systemd-resolved removed; resolv.conf managed by NetworkManager
#   * journald capped, debsecan cron for security announcements
#   * CPU governor = powersave

set -Euo pipefail
export DORIS_DIR="${DORIS_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
source "$DORIS_DIR/lib.sh"

header "HARDENING & PRIVACY"

announce "THE MEDICINE" "This is the suite that keeps the box calm: logs capped, weekly security scans, DNS handled right, and a firewall that came closed. Everything else security-wise stays stock Debian - AppArmor runs as the distro ships it. Every step backs up first and stays reversible - this is what makes a machine ROBUST, not loud."

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

# ── 3. /mnt/ramdisk tmpfs (general-purpose temp cache) ──
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

announce "THE PHONE LINE" "DNS decides who the box believes. On a trusted home router it pins there; on a public pipe it says so plainly - plaintext DNS on an untrusted link, and the browser's encrypted DNS (DoH) is the honest fix for the road. Same box, right posture for the road it is on."

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

# Direct (untrusted) link: no laptop-side DNS encryption any more (the
# stubby/DoT layer is retired). Say so plainly instead of pretending.
if [[ "$MODE" == "direct" ]]; then
    warn "  untrusted link: DNS rides DHCP in PLAINTEXT."
    warn "  For encrypted DNS on open networks use browser-level DoH"
    warn "  (e.g. Firefox/Chromium -> dns.nextdns.io) or your own DoT client."
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
announce "WIRELESS" "NetworkManager runs the wires and the airwaves here. Joining a network needs no mouse: open a terminal and run nmtui, arrow keys, activate a connection, done. The panel applet sits in lxpanel too, and the radio is switched on before you thought to ask."
if nmcli -t device 2>/dev/null | grep -qiE ':wifi:'; then
    sudo nmcli radio wifi on 2>/dev/null || true
    log "  wifi radio enabled for $(nmcli -t device | awk -F: '$2=="wifi" {print $1; exit}')."
fi

log "  resolv.conf: $(grep nameserver /etc/resolv.conf 2>/dev/null | tr '\n' ' ')"
if [[ -n "$DNS_SERVER" ]] && ! grep -q "nameserver $DNS_SERVER" /etc/resolv.conf; then
    warn "Expected nameserver $DNS_SERVER in resolv.conf but it is not there."
    warn "Check the NetworkManager connections (nmcli con show) and rerun task 05."
fi

announce "THE FRONT DOOR" "We firewall because it's good medicine - we don't want things crawling around our box doing nefarious shit causing all kinds of ruckus. Yours came closed and stays that way. Nothing to tend."

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
