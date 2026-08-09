#!/usr/bin/env bash
# browsah - Helium (Chromium fork) privacy installer
#   * patches Default/Preferences + Local State (prediction, passwords, GUIDs,
#     DoH secure, Helium services)
#   * installs the `helium` launcher wrapper on PATH (Optimization Guide off)
#   * opens the extension pages
#
#   usage: ./configure-helium.sh
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="$HOME/.config/net.imput.helium"
PREFS="$BASE/Default/Preferences"
LSTATE="$BASE/Local State"

banner() {
  echo "  Helium privacy bump"
  echo
}

if ! command -v helium >/dev/null 2>&1 && [ ! -x /usr/bin/helium ]; then
  echo "!! Helium is not installed. Install it first, then rerun this."
  exit 1
fi

if [ ! -f "$PREFS" ] || [ ! -f "$LSTATE" ]; then
  echo "!! No Helium profile found at $BASE"
  echo "   Start Helium once (it creates the profile), close it, then rerun this."
  exit 1
fi

if pgrep -x helium >/dev/null 2>&1; then
  echo "!! Helium is running. Close it first, then rerun this."
  exit 1
fi

banner
echo "  Profile: $BASE"

cp -a "$PREFS" "$PREFS.browsah-$(date +%Y%m%d-%H%M%S)"
cp -a "$LSTATE" "$LSTATE.browsah-$(date +%Y%m%d-%H%M%S)"
echo "  ✓ backups made (*.browsah-*)"

# ---------------------------------------------------------------------------
python3 - "$PREFS" "$LSTATE" <<'PY'
import json, sys
prefs, lstate = sys.argv[1], sys.argv[2]

d = json.load(open(prefs))
d.setdefault("net", {})["network_prediction_options"] = 0
d.setdefault("profile", {})["password_manager_leak_detection"] = {"enabled": False}
d["credentials_enable_service"] = False
d.pop("enterprise_profile_guid", None)
svcs = d.setdefault("helium", {}).setdefault("services", {})
svcs["enabled"] = False
svcs["user_consented"] = True
json.dump(d, open(prefs, "w"), indent=1)

s = json.load(open(lstate))
s["dns_over_https"] = {"mode": "secure", "templates": "https://chromium.dns.nextdns.io"}
for app in s.get("updateclientdata", {}).get("apps", {}).values():
    app.pop("pf", None)
    app.pop("fp", None)
json.dump(s, open(lstate, "w"), indent=1)
PY

echo "  ✓ Preferences patched (prediction off, no password leak check,"
echo "    no profile GUID, Helium services off)"
echo "  ✓ Local State patched (DoH secure via NextDNS, updater GUIDs cleared)"

# ---------------------------------------------------------------------------
echo
echo "  Installing the launcher wrapper (Optimization Guide off)..."
mkdir -p "$HOME/bin"
cp -a "$DIR/helium" "$HOME/bin/helium"
chmod +x "$HOME/bin/helium"
if command -v helium | grep -q "$HOME/bin"; then
  echo "  ✓ ~/bin/helium is shadowing the real binary - flags will apply."
else
  echo "  !! ~/bin is not before $(dirname "$(command -v helium)") on PATH."
  echo "     The wrapper is at $HOME/bin/helium - add ~/bin to PATH or"
  echo "     call it directly to get the flags."
fi

# ---------------------------------------------------------------------------
echo
echo "  Extensions: uBlock Origin is BUILT INTO Helium (nothing to install)."
echo "  Recommended addition (opened in Helium):"

# An extension counts as installed once its ID dir appears in Helium's
# Default/Extensions/ tree (which is where Chromium-family installs land).
ext_installed() {
  [ -d "$BASE/Default/Extensions/$1" ]
}

# watch_installed <name> <id> - poll a few minutes while the user clicks
# "Add to Chrome" on the page we opened. Returns 0 once installed.
watch_installed() {
  local name="$1" id="$2" waited=0
  echo "    watching for ${name} install (click 'Add to Chrome' on the page)..."
  while (( waited < 300 )); do
    ext_installed "$id" && { echo "  ✓ ${name} installed."; return 0; }
    sleep 3
    waited=$((waited + 3))
  done
  echo "    (${name} not seen within 5 min - add it later from the Web Store.)"
  return 1
}

ask() {
  local name="$1" url="$2" id="$3" ans="y"
  if ext_installed "$id"; then
    echo "  ✓ ${name} already installed - skipped"
    return 0
  fi
  # Only prompt when we have a keyboard; otherwise (background run) just open.
  if [[ -t 0 ]]; then
    read -rp "  Open page for ${name}? [Y/n] " ans || ans=""
  fi
  case "${ans:-y}" in
    y|Y|"") helium "$url" >/dev/null 2>&1 & watch_installed "$name" "$id" ;;
    *) echo "  - skipped" ;;
  esac
}

# Only KeePassXC is offered for Helium: ClearURLs and SponsorBlock have no
# Helium build, so offering them is dead weight (they failed twice before).
ask "KeePassXC-Browser" "https://chromewebstore.google.com/detail/oboonakemofpalcgghocfoadofidjkkk" "oboonakemofpalcgghocfoadofidjkkk"

echo
echo "  NOTE: Helium services are OFF (set above). Extension installs can fail"
echo "  silently because the Chrome Web Store fetches through Helium's"
echo "  service proxy. If the install above doesn't complete, briefly enable"
echo "  the service (in $HOME/.config/helium/Preferences set"
echo "  helium.services.enabled=true), install, then set it back to false."

echo
echo "  Done. Enjoy."
