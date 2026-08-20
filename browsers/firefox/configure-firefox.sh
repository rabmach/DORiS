#!/usr/bin/env bash
# browsah - Firefox privacy installer 2026 machiner opencode
# Applies firefox/user.js to a Firefox profile and opens the extension pages.
#
#   usage: ./configure-firefox.sh [profile-directory]
#   (no argument = auto-detect the default profile)
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
detect_profile() {
  # Prefer the profile that the installed Firefox uses; fall back to Default=1.
  python3 - "$@" <<'PY'
import configparser, os, sys
for base in (os.path.expanduser("~/.config/mozilla/firefox"),
             os.path.expanduser("~/.mozilla/firefox")):
    ini = os.path.join(base, "profiles.ini")
    if not os.path.isfile(ini):
        continue
    cp = configparser.ConfigParser()
    cp.optionxform = str
    cp.read(ini)
    default_name = None
    for sec in cp.sections():
        if sec.lower().startswith("install") and cp.has_option(sec, "Default"):
            default_name = cp.get(sec, "Default")
    for sec in cp.sections():
        if not sec.lower().startswith("profile"):
            continue
        path = cp.get(sec, "Path")
        name = cp.get(sec, "Name") if cp.has_option(sec, "Name") else ""
        rel = cp.getboolean(sec, "IsRelative", fallback=True)
        if default_name and default_name in (name, path):
            print(os.path.join(base, path) if rel else path)
            sys.exit(0)
    for sec in cp.sections():
        if sec.lower().startswith("profile") and cp.getboolean(sec, "Default", fallback=False):
            path = cp.get(sec, "Path")
            rel = cp.getboolean(sec, "IsRelative", fallback=True)
            print(os.path.join(base, path) if rel else path)
            sys.exit(0)
sys.exit(1)
PY
}
# ---------------------------------------------------------------------------
banner() {
  echo "  Firefox privacy bump"
  echo
}

PROFILE="${1:-}"
if [ -z "$PROFILE" ]; then
  if ! PROFILE="$(detect_profile)"; then
    echo "!! Could not find a Firefox profile automatically."
    echo "   Start Firefox once, or pass the profile directory as an argument."
    exit 1
  fi
fi
PROFILE="${PROFILE%/}"

if [ ! -d "$PROFILE" ]; then
  echo "!! Profile directory not found: $PROFILE"
  exit 1
fi

# Debian's firefox package execs the real binary as "firefox-bin"; match
# every name a running Firefox can carry (launcher, real binary, ESR).
if pgrep -x firefox >/dev/null 2>&1 || pgrep -x firefox-bin >/dev/null 2>&1 \
   || pgrep -x firefox-esr >/dev/null 2>&1; then
  echo "!! Firefox is running. Close it first, then rerun this."
  exit 1
fi

banner
echo "  Profile: $PROFILE"

# Backup whatever is already there (only the files we touch).
for f in prefs.js user.js; do
  if [ -f "$PROFILE/$f" ]; then
    cp -a "$PROFILE/$f" "$PROFILE/$f.browsah-$(date +%Y%m%d-%H%M%S)"
  fi
done

cp -a "$DIR/user.js" "$PROFILE/user.js"
echo "  ✓ installed user.js -> $PROFILE/user.js"
echo "  ✓ backup made (prefs.js.browsah-* / user.js.browsah-*)"
echo "  Next launch, Firefox applies these. (about:config changes revert on"
echo "  restart - edit $DIR/user.js instead to keep them.)"

# Default search -> DuckDuckGo (lives in search.json.mozlz4 since FF128).
if [ -f "$PROFILE/search.json.mozlz4" ]; then
  cp -a "$PROFILE/search.json.mozlz4" "$PROFILE/search.json.mozlz4.browsah-$(date +%Y%m%d-%H%M%S)"
fi
python3 "$DIR/search.py" "$PROFILE" || echo "  !! could not set DuckDuckGo as default"

# Search bar at the right of the toolbar, after a flexible space.
python3 "$DIR/ui.py" "$PROFILE" || echo "  !! could not position the search bar in the toolbar"

# RAM cache lives on /mnt/ramdisk - make sure it exists (and is a real tmpfs).
RAMDIR=/mnt/ramdisk
if ! mountpoint -q "$RAMDIR" 2>/dev/null; then
  echo
  echo "  !! $RAMDIR is not mounted - disk cache will stay on your SSD."
  echo "     Mount a tmpfs there (e.g. in /etc/fstab:"
  echo "     'tmpfs $RAMDIR tmpfs mode=1777,size=2G 0 0'), then rerun."
  echo "     Firefox will still work either way."
elif [ "$(findmnt -no FSTYPE "$RAMDIR" 2>/dev/null)" != "tmpfs" ]; then
  echo
  echo "  !! $RAMDIR is mounted but is $(findmnt -no FSTYPE "$RAMDIR") - not tmpfs."
  echo "     Cache there won't vanish on reboot. Mount a real tmpfs if you care."
else
  mkdir -p "$RAMDIR/firefox_cache"
  echo "  ✓ ramdisk cache: $RAMDIR/firefox_cache (tmpfs)"
fi

# ---------------------------------------------------------------------------
echo
echo "  Recommended extensions (privacy stack):"

# An extension counts as installed if its ID (dir name or .xpi) is in the
# profile's extensions/ folder, so we don't nag about what's already there.
ext_installed() {
  local extdir="$PROFILE/extensions" id="$1"
  [ -d "$extdir" ] && { [ -e "$extdir/$id" ] || [ -e "$extdir/$id.xpi" ]; }
}

# Open the add-on page in FIREFOX itself, not via xdg-open: the default
# browser is usually Helium now, and the extension would get offered there.
open_ff() {
  local url="$1"
  if command -v firefox >/dev/null 2>&1; then
    firefox "$url" &
  elif command -v firefox-esr >/dev/null 2>&1; then
    firefox-esr "$url" &
  else
    xdg-open "$url" >/dev/null 2>&1 || true
  fi
}

# watch_installed <name> <id> - poll the profile a few minutes while the user
# clicks "Add to Firefox" on the page we opened. Returns 0 once installed.
watch_installed() {
  local name="$1" id="$2" waited=0
  echo "    watching for ${name} install..."
  while (( waited < 300 )); do
    ext_installed "$id" && { echo "  ✓ ${name} installed."; return 0; }
    sleep 3
    waited=$((waited + 3))
  done
  echo "    (${name} not seen within 5 min - add it later from about:addons.)"
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
    y|Y|"")
      open_ff "$url" >/dev/null 2>&1 || true
      echo
      echo "    Firefox is opening the ${name} page."
      echo "    Click 'Add to Firefox', then alt-tab back here."
      echo
      watch_installed "$name" "$id"
      ;;
    *) echo "  - skipped" ;;
  esac
}

ask "uBlock Origin"                  "https://addons.mozilla.org/firefox/addon/ublock-origin/"          "uBlock0@raymondhill.net"
ask "ClearURLs"                      "https://addons.mozilla.org/firefox/addon/clearurls/"              "{74145f27-f039-47ce-a470-a662b129930a}"
ask "SponsorBlock"                   "https://addons.mozilla.org/firefox/addon/sponsorblock/"           "sponsorBlocker@ajay.app"
ask "Multi-Account Containers"       "https://addons.mozilla.org/firefox/addon/multi-account-containers/" "@testpilot-containers"
ask "KeePassXC-Browser"              "https://addons.mozilla.org/firefox/addon/keepassxc-browser/"      "keepassxc-browser@keepassxc.org"

echo
echo "  Done. Enjoy."
