#!/usr/bin/env bash
# 2026 machiner opencode
### part of the DORiS suite of goodness - 2026
# capture.sh - re-vendor the live box's state back into this kit.
#
#   usage: cd ~/DORiS && ./tools/capture.sh
#
# Copies (not moves):
#   ~/.config/*              -> config/
#   ~/bin/*                  -> bin/
#   ~/.local/share/{icons,themes,scripts} -> local/share/
#   ~/Pictures/*             -> Pictures/
#   dotfiles (.bashrc etc.)  -> home/
#   /etc hardening files     -> hardening/
#
# Then run ./tools/scrub.sh to strip usernames/keys before committing.
set -euo pipefail

DORIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
H="${HOME:?need HOME}"

echo "== capturing from $H into $DORIS_DIR =="

# app configs
rm -rf "$DORIS_DIR/config"
mkdir -p "$DORIS_DIR/config"
for item in "$H"/.config/*; do
    n=$(basename "$item")
    case "$n" in
        mozilla|net.imput.helium|doris-backups|systemd|opencode) continue ;;
    esac
    cp -a "$item" "$DORIS_DIR/config/$n"
done

# bin scripts
rm -rf "$DORIS_DIR/bin"
mkdir -p "$DORIS_DIR/bin"
cp -a "$H"/bin/. "$DORIS_DIR/bin/" 2>/dev/null || true
# browsers-setup is the assistant staged from browsers/post-login.sh (task 11),
# not a hand-maintained bin script - keep the kit source in browsers/ only.
rm -f "$DORIS_DIR/bin/browsers-setup"

# local assets
# Icons/themes now live in /usr/share (not ~/.local) so root apps match.
rm -rf "$DORIS_DIR/local"
mkdir -p "$DORIS_DIR/local/share"
for sub in icons themes scripts; do
    [[ -d "$H/.local/share/$sub" ]] && cp -a "$H/.local/share/$sub" "$DORIS_DIR/local/share/$sub"
done
# refresh the system-wide icon/theme copies into the kit
for ic in Dracula kora default; do
    [[ -d /usr/share/icons/$ic ]] && { rm -rf "$DORIS_DIR/local/share/icons/$ic"; cp -a "/usr/share/icons/$ic" "$DORIS_DIR/local/share/icons/"; }
done
if [[ -d /usr/share/themes ]]; then
    for th in /usr/share/themes/*; do
        [[ -d "$th" ]] && { rm -rf "$DORIS_DIR/local/share/themes/$(basename "$th")"; cp -a "$th" "$DORIS_DIR/local/share/themes/"; }
    done
fi

# wallpapers
rm -rf "$DORIS_DIR/Pictures"
mkdir -p "$DORIS_DIR/Pictures"
cp -a "$H"/Pictures/backgrounds "$DORIS_DIR/Pictures/" 2>/dev/null || true

# dotfiles
rm -rf "$DORIS_DIR/home"
mkdir -p "$DORIS_DIR/home"
for item in "$H"/.* "$H"/*; do
    n=$(basename "$item")
    case "$n" in .|..|.config|.local|.cache|.mozilla|.ssh|bin|Pictures|secrets) continue ;; esac
    [[ -e "$item" ]] || continue
    cp -a "$item" "$DORIS_DIR/home/$n"
done

# /etc hardening files (layout mirrors the hardening/ tree in the kit)
rm -rf "$DORIS_DIR/hardening"
mkdir -p "$DORIS_DIR/hardening"
hardening_copy() {
    local src="$1" rel="$2"
    if [[ -f "$src" ]]; then
        mkdir -p "$DORIS_DIR/hardening/$(dirname "$rel")"
        cp -a "$src" "$DORIS_DIR/hardening/$rel"
    fi
}
hardening_copy /etc/nftables.conf                          nftables/nftables.conf
hardening_copy /etc/modules-load.d/ftp-helper.conf         modules-load.d/ftp-helper.conf
hardening_copy /etc/sysctl.d/60-doris-performance.conf sysctl.d/60-doris-performance.conf
hardening_copy /etc/systemd/system/cpufreq-governor.service systemd/cpufreq-governor.service
hardening_copy /etc/cron.d/debsecan                        cron.d/debsecan
hardening_copy /etc/systemd/journald.conf                  journald/journald.conf
hardening_copy /etc/apparmor.d/helium-bin                  apparmor/helium-bin
hardening_copy /etc/apparmor.d/helium-bin.dist-default-allow apparmor/helium-bin.dist-default-allow
hardening_copy /etc/apparmor.d/sublime-text                apparmor/sublime-text
hardening_copy /etc/stubby/stubby.yml                      stubby/stubby.yml
mkdir -p "$DORIS_DIR/hardening/auditd"
sudo cp -a /etc/audit/auditd.conf "$DORIS_DIR/hardening/auditd/" 2>/dev/null || true

echo "== done. run ./tools/scrub.sh next, then review the diff =="
