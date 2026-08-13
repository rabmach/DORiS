#!/usr/bin/env bash
# 2026 machiner opencode
### part of the DORiS suite of goodness - debian openbox restoration script(s) - 2026
### browsers-setup - interactive browser privacy assistant
###
### Runs from your X session (startx / display manager). Pick a browser from
### the menu; it launches the browser for you, waits for your first run, then
### applies the browsah privacy configs (user.js, DDG, DoH secure, GTK theme,
### ramdisk cache) and walks you through the extension installs, watching
### the profile until each one lands.
###
###   usage: browsers-setup [firefox|helium|both]   (no arg -> menu)
###
### Per-browser done markers: ~/.config/doris/browsers-done-firefox and
### browsers-done-helium. Safe to rerun: finished steps are skipped.
set -Euo pipefail

if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
    echo "!! No display found. This must run from your X session after login"
    echo "   (startx / display manager), not from a tty."
    exit 1
fi

say() { printf '  %s\n' "$*"; }
banner() {
    echo
    echo "  ------------------------------------------------------------"
    echo "  $*"
    echo "  ------------------------------------------------------------"
}

DORIS_DIR_CONFIG="$HOME/.config/doris"
FF_DONE="$DORIS_DIR_CONFIG/browsers-done-firefox"
HE_DONE="$DORIS_DIR_CONFIG/browsers-done-helium"
# One marker from the old pre-assistant flow; drop it so the menu re-offers.
rm -f "$DORIS_DIR_CONFIG/browsers-done"

# browser_alive <firefox|helium> - Debian's firefox ships as a launcher
# binary named "firefox" that execv()s the real "firefox-bin"; pgrep -x
# "firefox" alone never matches a running browser. Match the real comm names.
browser_alive() {
    case "$1" in
        firefox) pgrep -x firefox    >/dev/null 2>&1 || \
                 pgrep -x firefox-bin >/dev/null 2>&1 || \
                 pgrep -x firefox-esr >/dev/null 2>&1 ;;
        helium)  pgrep -x helium >/dev/null 2>&1 ;;
    esac
}

# ── clear stale profile locks (Chromium/Firefox singleton files survive
#    profile dumps and make the browser refuse to start, blaming a lock
#    "on another computer"). Only safe when the browsers are not running.
clear_stale_locks() {
    local dir
    for dir in "$HOME/.config/net.imput.helium" "$HOME/.config/mozilla/firefox" "$HOME/.mozilla/firefox"; do
        [[ -d "$dir" ]] || continue
        if browser_alive firefox || browser_alive helium; then
            echo "!! A browser is running - close it first, then rerun browsers-setup."
            return 1
        fi
        find "$dir" -maxdepth 1 \( -name 'SingletonLock' -o -name 'SingletonSocket' \
            -o -name 'SingletonCookie' -o -name 'parent.lock' -o -name 'lock' \) \
            -delete 2>/dev/null || true
    done
    return 0
}

# ── locate the browsah configs: ~/browsah (your repo) or the doris kit ──
BROWSAH_DIR="$HOME/browsah"
KIT_DIR="${DORIS_DIR:-$HOME/DORiS}/browsers"
if [[ ! -f "$BROWSAH_DIR/firefox/configure-firefox.sh" ]]; then
    if [[ -f "$KIT_DIR/firefox/configure-firefox.sh" ]]; then
        BROWSAH_DIR="$KIT_DIR"
        say "(using the doris kit copy of the browsah configs)"
    else
        echo "!! browsah configs not found (~/browsah or $KIT_DIR)."
        exit 1
    fi
fi

glob_ready() { compgen -G "$1" >/dev/null 2>&1; }

# any_glob_ready <glob-array-name>  -> true if ANY of the globs matches
any_glob_ready() {
    local -n globs="$1"
    local g
    for g in "${globs[@]}"; do
        glob_ready "$g" && return 0
    done
    return 1
}

# ensure_profile <glob-array-name> <process-name> <label> <launch-cmd...>
# If the profile is missing we LAUNCH the browser ourselves; waits (up to 20
# min) for the first run to finish AND the browser to be closed. If the
# profile exists but the browser is running, waits for it to close.
ensure_profile() {
    local globname="$1"
    local proc="$2" label="$3"
    shift 3
    if any_glob_ready "$globname"; then
        if browser_alive "$proc"; then
            echo
            echo "  >>> $label is running <<<"
            echo "  Close it now, then press Enter. I will continue once it is closed."
            echo
            read -rp "  [Enter to continue] " _ || true
            while browser_alive "$proc"; do
                sleep 2
            done
            say "OK $label closed."
        else
            say "OK $label profile already exists."
        fi
        return 0
    fi
    echo
    echo "  >>> $label first run <<<"
    echo "  Launching $label for you now. Go through its first-run setup,"
    echo "  then CLOSE it. I am watching the profile and will continue..."
    echo
    "$@" >/dev/null 2>&1 &
    local waited=0 seen=0
    while (( waited < 1200 )); do
        if browser_alive "$proc"; then
            # browser is running; mark that we saw it. Only once it has been
            # running AND is now closed do we trust the profile glob.
            seen=1
        elif (( seen )) && any_glob_ready "$globname"; then
            sleep 1
            say "OK $label profile detected."
            return 0
        fi
        sleep 3
        waited=$((waited + 3))
    done
    echo "!! Timed out waiting for $label. Close it and rerun browsers-setup."
    return 1
}

do_firefox() {
    if [[ -f "$FF_DONE" ]]; then
        say "Firefox already set up (marker: $FF_DONE)."
        return 0
    fi
    banner "== Firefox =="
    # Debian firefox (>= 127ish) uses the XDG path ~/.config/mozilla/firefox;
    # older installs and some profiles dump use ~/.mozilla/firefox. Match both.
    if ensure_profile FF_GLOB firefox "Firefox" firefox; then
        bash "$BROWSAH_DIR/firefox/configure-firefox.sh" \
            || echo "  !! Firefox config had a problem (see above)."
        mkdir -p "$DORIS_DIR_CONFIG"
        touch "$FF_DONE"
        say "Firefox step complete."
    fi
}

do_helium() {
    if [[ -f "$HE_DONE" ]]; then
        say "Helium already set up (marker: $HE_DONE)."
        return 0
    fi
    banner "== Helium =="
    if ensure_profile HE_GLOB helium "Helium" helium; then
        bash "$BROWSAH_DIR/helium/configure-helium.sh" \
            || echo "  !! Helium config had a problem (see above)."
        mkdir -p "$DORIS_DIR_CONFIG"
        touch "$HE_DONE"
        say "Helium step complete."
    fi
}

# BUG-008: profiles.ini is written by the browser at SPAWN time, long before
# the first-run wizard finishes - so it is not a "real profile" signal. A
# profile with prefs.js is initialized (first-run done). Match that instead.
FF_GLOB=("$HOME/.config/mozilla/firefox/*/prefs.js" "$HOME/.mozilla/firefox/*/prefs.js")
HE_GLOB=("$HOME/.config/net.imput.helium/Default/Preferences")

run_menu() {
    while true; do
        echo
        echo "  ------------------------------------------------------------"
        echo "  DORiS browser privacy setup"
        echo "  ------------------------------------------------------------"
        [[ -f "$FF_DONE" ]] || echo "    1) Set up Firefox"
        [[ -f "$HE_DONE" ]] || echo "    2) Set up Helium"
        echo "    3) Set up both (Firefox, then Helium)"
        echo "    4) Skip for now"
        echo
        read -rp "  choice: " choice || true
        case "${choice:-}" in
            1) do_firefox ;;
            2) do_helium ;;
            3) do_firefox; do_helium ;;
            4|"") echo "  - skipped for now."; return 0 ;;
            *) echo "  ?? pick 1-4." ;;
        esac
        [[ -f "$FF_DONE" && -f "$HE_DONE" ]] && break
    done
    banner "Done"
    say "Firefox and Helium are configured. Config applies on next launch."
    say "Remember: Firefox first, then Helium, if you ever restore a profile dump."
}

banner "DORiS browser privacy setup"
if ! clear_stale_locks; then
    exit 1
fi

case "${1:-}" in
    firefox)
        if ! command -v firefox >/dev/null 2>&1 && ! command -v firefox-esr >/dev/null 2>&1; then
            echo "  !! firefox not installed. (system task 02/03)"
        else
            do_firefox
        fi
        ;;
    helium)
        if ! command -v helium >/dev/null 2>&1 && [[ ! -x /usr/bin/helium ]]; then
            echo "  !! helium-bin not installed. (system task 02/03)"
        else
            do_helium
        fi
        ;;
    both)
        [[ -f "$FF_DONE" && -f "$HE_DONE" ]] || run_menu
        ;;
    *)
        run_menu
        ;;
esac
exit 0
