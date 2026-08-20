#!/usr/bin/env bash
# browsah - Helium (Chromium fork) privacy installer
#   * patches Default/Preferences + Local State (prediction, passwords, GUIDs,
#     DoH secure, system GTK theme)
#   * installs the `helium` launcher wrapper on PATH (Optimization Guide off)
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
# SystemTheme enum (ui/color/system_theme.h): 1 = kGtk. Makes Helium follow
# the desktop GTK theme (helium://settings appearance -> "Use GTK theme").
d.setdefault("extensions", {}).setdefault("theme", {})["system_theme"] = 1
# Privacy: no search suggestions, global privacy control header.
d.setdefault("search", {})["suggest_enabled"] = False
d.setdefault("helium", {})["global_privacy_control"] = True
# Helium browser prefs: MRU tab cycling (ctrl+tab), zen/frameless mode,
# completed onboarding so the first-run wizard does not reappear.
hbr = d.setdefault("helium", {}).setdefault("browser", {})
hbr["mru_tab_cycling"] = True
hbr["zen_mode"] = True
d.setdefault("helium", {})["completed_onboarding"] = True
# Helium services are ENABLED deliberately (idempotent: older runs of this
# script set them false, and a re-run must re-enable them): the extension
# proxy ("ext_proxy") is what fetches Chrome Web Store downloads/updates, so
# services off silently breaks extension installs. Trade-off: Helium talks to
# its own service endpoints (bangs, spellcheck, update checks).
svcs = d.setdefault("helium", {}).setdefault("services", {})
svcs["enabled"] = True
svcs["ext_proxy"] = True
svcs["user_consented"] = True
svcs["bangs"] = False
svcs["browser_updates"] = False
svcs["spellcheck_files"] = False
svcs["ublock_assets"] = False
json.dump(d, open(prefs, "w"), indent=1)

s = json.load(open(lstate))
s["dns_over_https"] = {"mode": "secure", "templates": "https://dns.quad9.net/dns-query"}
for app in s.get("updateclientdata", {}).get("apps", {}).values():
    app.pop("pf", None)
    app.pop("fp", None)
json.dump(s, open(lstate, "w"), indent=1)
PY

echo "  ✓ Preferences patched (prediction off, no password leak check,"
echo "    no profile GUID, system GTK theme on, search suggestions off,"
echo "    MRU tab cycling on, zen mode on, global privacy control on,"
echo "    Helium services enabled so the extension proxy works)"
echo "  ✓ Local State patched (DoH secure via Quad9, updater GUIDs cleared)"

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
echo "  KeePassXC-Browser is not offered by the kit - install it yourself from"
echo "  the Web Store if you want it (the kit only sets security configs)."

echo
echo "  Done. Enjoy."
