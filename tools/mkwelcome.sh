#!/usr/bin/env bash
# 2026 machiner opencode
### part of the DORiS suite of goodness - debian openbox restoration script(s) - 2026
### mkwelcome.sh - generate the DORiS first-login welcome message.
###
### Reads the KIT (config/openbox/rc.xml, home/.bash_aliases,
### packages/core.list, hardening/) plus the /etc/doris state and prints a
### pretty, informative welcome screen to stdout. Called by user task 12;
### also handy on its own:  ./tools/mkwelcome.sh
###
### The keybinds and aliases sections are DERIVED from the kit, so when you
### add a keybind to rc.xml or an alias to .bash_aliases, re-run
### user-setup.sh (task 12) to regenerate the welcome.
set -Euo pipefail

DORIS_DIR="${DORIS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
RC="$DORIS_DIR/config/openbox/rc.xml"
ALIASES="$DORIS_DIR/home/.bash_aliases"
CORE_LIST="$DORIS_DIR/packages/core.list"
HARDEN="$DORIS_DIR/hardening"

# ── helpers ──────────────────────────────────────────────────
modifier() { # C->Ctrl A->Alt S->Shift W->Super, joined with +
    local key="$1" out=""
    [[ "$key" == *C-* ]] && out="${out}Ctrl+"
    [[ "$key" == *A-* ]] && out="${out}Alt+"
    [[ "$key" == *S-* ]] && out="${out}Shift+"
    [[ "$key" == *W-* ]] && out="${out}Super+"
    key="${key##*-}"
    key="${key//Left/Left}"; key="${key//Right/Right}"; key="${key//Up/Up}"; key="${key//Down/Down}"
    echo "${out}${key}"
}

# ── title ────────────────────────────────────────────────────
echo "     welcome back to your DORiS desktop.     "
echo "  ----------------------------------------------------------"

# ── security ─────────────────────────────────────────────────
echo
echo "  SECURITY - this system is set up and watching its own back:"
MODE="$(cat /etc/doris/mode 2>/dev/null || echo unknown)"
case "$MODE" in
    direct)
        echo "   * nftables firewall: default-DENY in and out (see /etc/nftables.conf)"
        echo "   * DNS:  encrypted for EVERYTHING (stubby/DoT via 127.0.0.1) -"
        echo "           your link is untrusted, so no plaintext DNS ever leaves."
        ;;
    router)
        DNS="$(cat /etc/doris/router-ip 2>/dev/null || echo 192.168.1.1)"
        echo "   * nftables firewall: default-DENY in and out (see /etc/nftables.conf)"
        echo "   * DNS:  pinned to your trusted router ($DNS). Browser DoH (NextDNS) covers the rest."
        ;;
    *) echo "   * nftables firewall: default-DENY in and out (see /etc/nftables.conf)" ;;
esac
# AppArmor profile counts, live from sysfs (world-readable, no root needed).
# Some profiles nest children (e.g. plasmashell//QtWebEngineProcess), so count
# every mode file, not just top-level dirs.
AA_BASE=/sys/kernel/security/apparmor/policy/profiles
if [[ -d "$AA_BASE" ]] && command -v grep >/dev/null 2>&1; then
    AA_MODES=$(find "$AA_BASE" -name mode 2>/dev/null)
    AA_TOTAL=$(printf '%s\n' "$AA_MODES" | wc -l)
    AA_ENFORCE=$(grep -l enforce $AA_MODES 2>/dev/null | wc -l)
    AA_COMPLAIN=$(grep -l complain $AA_MODES 2>/dev/null | wc -l)
    if [[ "$AA_TOTAL" -gt 0 ]]; then
        echo "   * AppArmor: ${AA_TOTAL} profiles active (${AA_ENFORCE} enforce, ${AA_COMPLAIN} complain) -"
        echo "     auditd logs denials; review complain-mode profiles with"
        echo "     ~/bin/apparmor-review, then enforce with sudo aa-enforce."
    else
        echo "   * AppArmor: module present but no profiles loaded yet."
    fi
else
    echo "   * AppArmor: not active on this kernel (see /sys/kernel/security/apparmor)."
fi
echo "   * journald capped, debsecan weekly CVE scan, /mnt/ramdisk tmpfs for"
echo "     browser caches (history/cache never touch the disk)."

echo
echo "  TIMERS / SCHEDULED JOBS:"
for t in "$HARDEN"/systemd/*.timer; do
    [[ -f "$t" ]] || continue
    echo "   * systemd user timer: $(basename "$t" .timer)"
done
[[ -f "$HARDEN/cron.d/debsecan" ]] && echo "   * cron: debsecan (weekly security audit)"

echo
echo "  TO DO ONCE (credentials - be verbose, be kind):"
echo "   * pianobar  -> edit ~/.config/pianobar/config : set your PANDORA"
echo "                  username and uncomment password_command. That music"
echo "                  won't stream itself."
echo "   * weather   -> put your OpenWeatherMap API key in ~/.config/weather_sh.rc"
echo "   * keepassxc -> open it and create/open your database. Do this FIRST;"
echo "                  the browser extension talks to it."
echo "   * claws-mail-> add your email accounts (account wizard)."
echo "   * filezilla -> save your FTP/SFTP sites."
echo "   * github-desktop -> sign in."
echo "   * ~/bin/nbp needs a gpg secret key as your default (see README) before it works."

echo
echo "  BROWSERS (first login opens the setup menu):"
echo "   * the welcome terminal offers Firefox / Helium / both. The assistant"
echo "     LAUNCHES each browser for you, waits for the first run, then applies"
echo "     the privacy config and walks you through the add-ons."
echo "   * uBlock Origin is built into Helium; the kit offers no Helium add-ons."

# ── keybinds ─────────────────────────────────────────────────
echo
echo "  HANDY KEYBINDS (from your openbox rc.xml):"
if [[ -f "$RC" ]] && command -v python3 >/dev/null 2>&1; then
    # human descriptions for keys where the command alone doesn't say enough
    declare -A KB_DESC=(
        [W-k]="keepassxc"
        [W-p]="pianobar, control-pianobar.sh p"
        [W-t]="x-terminal-emulator, alacritty"
        [W-o]="obr, reconfig and restart openbox"
        [W-q]="rec, record to flac"
        [W-u]="weather, set it up first"
        [W-n]="mpv randomizing ~/Music, see ~/bin/tunes"
        [C-A-n]="nag-zen, for a handy reminder"
        [C-A-p]="pick.sh, random movie picker"
        [C-A-T]="same as super+n"
    )
    python3 - "$RC" <<'PY' | while IFS=$'\t' read -r key label; do
import sys, xml.etree.ElementTree as ET
tree = ET.parse(sys.argv[1]); root = tree.getroot()
def ln(e):  # local name (openbox rc.xml is namespaced)
    return e.tag.split('}')[-1]
rows = []
for kb in root.iter():
    if ln(kb) != 'keybind':
        continue
    key = kb.get('key')
    acts = [a for a in kb if ln(a) == 'action']
    if not acts:
        continue
    name = acts[0].get('name', '')
    cmd = ''
    for ch in acts[0]:
        if ln(ch) == 'command':
            cmd = (ch.text or '').strip().split('/')[-1].replace('\\ ', ' ')
            break
        if ln(ch) == 'execute':
            ex = (ch.text or '').strip()
            if ex and ' ' not in ex:
                cmd = ex.split('/')[-1]
    if name == 'Execute':
        rows.append((key, cmd or 'execute'))
    elif name in ('ShowMenu', 'ToggleShowDesktop', 'NextWindow', 'PreviousWindow', 'Iconify', 'Close', 'ToggleFullscreen', 'ToggleMaximize'):
        rows.append((key, name))
seen = set()
for key, label in rows:
    if key in seen:
        continue
    seen.add(key)
    print(f"{key}\t{label}")
PY
        printf "   %-18s %s\n" "$(modifier "$key")" "${KB_DESC[$key]:-$label}"
    done
else
    echo "   (python3 not available at build time - keybinds omitted)"
fi

# ── aliases ──────────────────────────────────────────────────
echo
echo "  HANDY ALIASES:"
if [[ -f "$ALIASES" ]]; then
    for a in otto cpf install remove search update upgrade services failed bp del fstab src su bd mount apps list show edit cat; do
        def=$(grep -E "^alias ${a}=" "$ALIASES" | head -1 | sed -E 's/^alias //' | cut -c1-70)
        [[ -n "$def" ]] && printf "   %-12s %s\n" "$a" "$def"
    done
    echo "   (full list:  cat ~/.bash_aliases)"
fi

# ── admin apps ───────────────────────────────────────────────
echo
echo "  HANDY ADMIN / MANAGEMENT APPS (just installed):"
for a in synaptic gparted "nm-connection-editor (network)" "system-config-printer (printing)" \
         seahorse keepassxc filezilla claws-mail github-desktop solaar btop s-tui nvtop vnstat catfish; do
    printf "   * %s\n" "$a"
done
echo "   * ~/bin/gov (cpu governor), ~/bin/weather, ~/bin/tunes (pianobar),"
echo "     ~/bin/nbp (notes backup), ~/bin/sysinfo.sh, ~/bin/nag"

# ── dad joke ─────────────────────────────────────────────────
JOKES=(
  "Why do programmers prefer dark mode? Because light attracts bugs."
  "How many programmers does it take to change a light bulb? None - that's a hardware problem."
  "I would tell you a UDP joke, but you might not get it."
  "There are only 10 kinds of people: those who understand binary and those who don't."
  "A SQL query walks into a bar, goes up to two tables and asks: can I JOIN you?"
  "Why did the openbox user get suspended from school? Too many window violations."
)
echo
echo "  $((RANDOM % ${#JOKES[@]}))" >/dev/null   # keep $RANDOM honest
printf '  Dad joke for today:  %s\n' "${JOKES[$((RANDOM % ${#JOKES[@]}))]}"

echo
echo "  Later, bitches!"
echo "  ----------------------------------------------------------"
exit 0
