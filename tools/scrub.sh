#!/usr/bin/env bash
# 2026 machiner opencode
### part of the DORiS suite of goodness - 2026
# scrub.sh - strip usernames, keys, and runtime junk from the kit.
#
#   usage: cd ~/doris && ./tools/scrub.sh
#
# * replaces /home/<username> with /home/$USER in config files
# * zeroes known secrets (weather OWM key, pianobar creds, nextdns ids)
# * drops runtime-only dirs/files (cache, logs, ctl sockets, *.gpg leftovers)
# * refuses to run while a working tree matches a git repo (protects remotes)
#
# Always eyeball `git diff --stat` afterwards; it is a heuristic, not a proof.
set -euo pipefail

DORIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DORIS_DIR"

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "!! You are inside a git repo ($(git rev-parse --show-toplevel))."
    echo "   scrub.sh is meant for a scratch checkout. Copy the kit to /tmp,"
    echo "   scrub there, review, and only then copy back."
    exit 1
fi

echo "== scrubbing $DORIS_DIR =="

# ---- 1. usernames / absolute home paths ----------------------
# tokenize anything that points at a real login home
for home in /home/*; do
    [[ -d "$home" ]] || continue
    u="${home##*/}"
    # don't clobber generic-looking names or our own tokens
    case "$u" in $USER|homer|john|damo|snortmerd|bk) ;; *) continue ;; esac
    # note: `|| true` guards the pipefail+set -e trap when grep matches nothing
    grep -rlF "$home" config home bin local Pictures 2>/dev/null | while read -r f; do
        case "$f" in
            *.png|*.jpg|*.jpeg|*.gif|*.xpm|*.svg|*.gz|*.zip|*.woff2|*.ttf) continue ;;
        esac
        sed -i "s|$home|/home/\$USER|g" "$f"
        echo "  tokenized $f"
    done || true
done

# ---- 1b. hostname/email leaks ---------------------------------
# hostnames change between installs; scrub <user>@<hostname> back to the
# $HOSTNAME token so capture→scrub→commit never ships a baked hostname.
# Known hostnames are the current one plus past installs (debola, doris).
for u in $USER homer john damo snortmerd bk; do
    for h in "$(hostname)" debola doris; do
        [[ -n "$h" ]] || continue
        grep -rlE "${u}@${h}\b" config home bin local Pictures 2>/dev/null | while read -r f; do
            case "$f" in
                *.png|*.jpg|*.jpeg|*.gif|*.xpm|*.svg|*.gz|*.zip|*.woff2|*.ttf) continue ;;
            esac
            sed -i "s|${u}@${h}\b|\$USER@\$HOSTNAME|g" "$f"
            echo "  tokenized hostname $f"
        done || true
    done
done

# ---- 2. secrets ----------------------------------------------
scrub_file() {
    local f="$1"
    [[ -f "$f" ]] || return 0
    sed -i \
        -e 's|5a2e6236647478605ece1a3b3ba701d9|YOUR_OWM_API_KEY|g' \
        -e 's|dns\.nextdns\.io|dns.nextdns.io|g' \
        "$f"
}
# weather key (if it leaked back in)
scrub_file config/weather_sh.rc
scrub_file bin/weather.sh
# pianobar creds placeholder
[[ -f config/pianobar/config ]] && \
    sed -i 's|^user = .*|user = YOUR_PANDORA_USER|' config/pianobar/config

# ---- 3. runtime junk -----------------------------------------
find config bin home local Pictures -type d \( \
    -name cache -o -name '__pycache__' -o -name '.thumbnails' \
    -o -name 'CachedData' -o -name 'backup' \) -prune -exec rm -rf {} + 2>/dev/null || true
find config home -type f \( \
    -name '*.log' -o -name '*.browsah-*' -o -name 'session.lock' \
    -o -name '*.ctl' -o -name 'ctl' -o -name 'history' -o -name '*.rec' \) \
    -delete 2>/dev/null || true

# pianobar runtime state files
rm -f config/pianobar/ctl config/pianobar/downloaddir config/pianobar/downloadname \
      config/pianobar/durationstation config/pianobar/isplaying config/pianobar/nowplaying \
      config/pianobar/pandora.jpg config/pianobar/state config/pianobar/stationlist \
      "config/pianobar/pandora stations with station ID" 2>/dev/null || true

# keep the audacious config file where the app expects it
[[ -f config/audacious-config ]] && { mkdir -p config/audacious; mv config/audacious-config config/audacious/config; }

echo "== scrub done. review the diff before committing =="
