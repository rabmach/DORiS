#!/usr/bin/env bash
# 2026 machiner opencode
### DORiS - Debian Openbox Restoration Script
### lib.sh - shared library for both runners (restore.sh = system, user-setup.sh = per-user).
###
### Expects $DORIS_DIR to be exported by the runner before sourcing.

set -Euo pipefail

export DORIS_DIR="${DORIS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
export DORIS_SYSTEM_DIR="$DORIS_DIR/tasks/system"
export DORIS_USER_DIR="$DORIS_DIR/tasks/user"
export LOG_FILE="$DORIS_DIR/restore.log"
export ERROR_FILE="$DORIS_DIR/restore-errors.log"
export BACKUP_BASE="$DORIS_DIR/backups"
export BACKUP_DIR="$BACKUP_BASE/$(date +%Y%m%d-%H%M%S)"

export CURRENT_USER="${SUDO_USER:-$(whoami)}"
export CURRENT_HOME
CURRENT_HOME="$(getent passwd "$CURRENT_USER" | cut -d: -f6 2>/dev/null)"
[[ -n "$CURRENT_HOME" ]] || CURRENT_HOME="$HOME"

# System state markers live here (root-owned, survives across users).
export DORIS_STATE="/etc/doris"
export DORIS_MODE_FILE="$DORIS_STATE/mode"          # router | direct | unknown
export DORIS_ROUTER_IP_FILE="$DORIS_STATE/router-ip"
export DORIS_INSTALL_MARKER="$DORIS_STATE/installed"

# Per-user state (first-login welcome gating, etc).
export DORIS_USER_STATE="$CURRENT_HOME/.config/doris"

export ASSET_ICONS="$DORIS_DIR/local/share/icons"
export ASSET_THEMES="$DORIS_DIR/local/share/themes"
export ASSET_SCRIPTS="$DORIS_DIR/local/share/scripts"
export HARDEN_DIR="$DORIS_DIR/hardening"
export BROWSERS_DIR="$DORIS_DIR/browsers"

# A reasonable default router DNS when the gateway can't be detected.
export DEFAULT_ROUTER_DNS="${DNS_SERVER:-192.168.1.1}"

mkdir -p "$(dirname "$LOG_FILE")" "$BACKUP_BASE"

# ── Logging ─────────────────────────────────────────────────
log()  { echo "[$(date '+%H:%M:%S')]  $*" | tee -a "$LOG_FILE"; }
info() { echo "  -> $*" | tee -a "$LOG_FILE"; }
warn() { echo "  [WARN] $*" | tee -a "$LOG_FILE"; echo "[WARN] $*" >> "$ERROR_FILE"; }
error(){ echo "  [ERROR] $*" | tee -a "$LOG_FILE" >&2; echo "[ERROR] $*" >> "$ERROR_FILE"; }
die()  { error "$*"; exit 2; }

header() {
    echo "" | tee -a "$LOG_FILE"
    echo "==============================================" | tee -a "$LOG_FILE"
    echo "  $*" | tee -a "$LOG_FILE"
    echo "==============================================" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
}

# ── Privilege helpers ───────────────────────────────────────
require_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        die "This part of DORiS must run as root. Use:  sudo $0 $*"
    fi
    log "Running with root privileges (uid 0)."
}

# ── CPU vendor detection ────────────────────────────────────
cpu_vendor() {
    grep -m1 -o 'GenuineIntel\|AuthenticAMD' /proc/cpuinfo 2>/dev/null || echo "unknown"
}
is_intel() { [[ "$(cpu_vendor)" == "GenuineIntel" ]]; }
is_amd()   { [[ "$(cpu_vendor)" == "AuthenticAMD" ]]; }

# ── Package helpers ─────────────────────────────────────────
is_installed() {
    [[ "$(dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null)" == "installed" ]]
}

apt_update() {
    if [[ "${DORIS_APT_UPDATED:-0}" != "1" ]]; then
        log "Running apt-get update (first pass)..."
        sudo apt-get update 2>&1 | tee -a "$LOG_FILE" >/dev/null || warn "apt-get update reported problems."
        export DORIS_APT_UPDATED=1
    fi
}

# One pass for the whole list, then a per-package fallback on
# real failure, then repair any broken dependency state.
apt_install() {
    local -a missing=()
    local pkg
    for pkg in "$@"; do
        is_installed "$pkg" || missing+=("$pkg")
    done
    if [[ ${#missing[@]} -eq 0 ]]; then
        info "All requested packages already installed."
        return 0
    fi
    apt_update
    info "Installing ${#missing[@]} packages (this may take a while)..."
    if sudo apt-get install -y --no-install-recommends "${missing[@]}" 2>&1 | tee -a "$LOG_FILE"; then
        log "Bulk install succeeded."
        return 0
    fi
    warn "Bulk install had failures; trying each package individually..."
    local failed=()
    for pkg in "${missing[@]}"; do
        if sudo apt-get install -y --no-install-recommends "$pkg" 2>&1 | tee -a "$LOG_FILE"; then
            log "  installed: $pkg"
        else
            warn "  failed to install: $pkg"
            failed+=("$pkg")
        fi
    done
    sudo apt-get -f install -y 2>&1 | tee -a "$LOG_FILE" >/dev/null || true
    if [[ ${#failed[@]} -gt 0 ]]; then
        warn "Unresolved packages: ${failed[*]}"
        return 1
    fi
    return 0
}

install_pkg_list() {
    local list="$1"
    local -a pkgs=()
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%%#*}"               # strip comments
        line="${line//[[:space:]]/}"     # drop whitespace
        [[ -n "$line" ]] && pkgs+=("$line")
    done < "$list"
    apt_install "${pkgs[@]}"
}

# ── Backup helpers ───────────────────────────────────────────
ensure_dir() { mkdir -p "$@"; }

backup_file() {
    local target="$1"
    if [[ -e "$target" ]]; then
        local rel="${target#/}"
        local dest="$BACKUP_DIR/$rel"
        mkdir -p "$(dirname "$dest")"
        chown -R "$CURRENT_USER" "$BACKUP_DIR" 2>/dev/null || true
        cp -a "$target" "$dest"
        chown -R "$CURRENT_USER" "$dest" 2>/dev/null || true
        log "  Backed up: $target"
        return 0
    fi
    return 1
}

backup_and_copy() {
    local src="$1" dest="$2"
    if [[ -e "$dest" ]]; then
        backup_file "$dest"
    fi
    mkdir -p "$(dirname "$dest")"
    cp -a "$src" "$dest"
}

backup_and_copy_dir() {
    local src="$1" dest="$2"
    if [[ -d "$dest" ]]; then
        backup_file "$dest"
        rm -rf "$dest"
    fi
    mkdir -p "$(dirname "$dest")"
    cp -a "$src" "$dest"
}

zip_backups() {
    if [[ -d "$BACKUP_DIR" ]] && [[ -n "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
        info "Creating backup archive..."
        (cd "$BACKUP_BASE" && tar czf "$(basename "$BACKUP_DIR").tar.gz" "$(basename "$BACKUP_DIR")" 2>/dev/null && rm -rf "$BACKUP_DIR")
        chown "$CURRENT_USER" "$BACKUP_BASE/$(basename "$BACKUP_DIR").tar.gz" 2>/dev/null || true
        log "  Backup archived: $(basename "$BACKUP_DIR").tar.gz"
    fi
}

# Files written during a sudo-run user-setup would be root-owned; make sure
# everything we touch belongs to the user we are setting up.
own_as_user() {
    [[ "$(id -u)" -eq 0 ]] || return 0
    local path
    for path in "$@"; do
        [[ -e "$path" ]] || continue
        chown -R "$CURRENT_USER":"$CURRENT_USER" "$path" 2>/dev/null || true
    done
}

# Settle $CURRENT_HOME ownership to $CURRENT_USER BEFORE any task runs.
# user-setup.sh may be invoked via sudo (files land root-owned) or by the
# user themselves (and the home may be root-owned from a botched run or a
# previous install). Doing this up front is what makes run-as-user steps
# (e.g. xdg-mime in task 10) actually succeed - the old code only chowned at
# the END of each task, so fresh installs spewed "mkdir: Permission denied"
# and the thunar/x-file-manager tweak silently never applied.
# This mirrors the manual `sudo chown -R user:user /home/user` fix. No-op
# unless we are root (a plain-user run is already correct after settle).
settle_ownership() {
    [[ "$(id -u)" -eq 0 ]] || return 0
    [[ -n "$CURRENT_USER" && "$CURRENT_USER" != "root" ]] || return 0
    if [[ ! -d "$CURRENT_HOME" ]]; then
        mkdir -p "$CURRENT_HOME"
        chown "$CURRENT_USER":"$CURRENT_USER" "$CURRENT_HOME"
    fi
    chown -R "$CURRENT_USER":"$CURRENT_USER" "$CURRENT_HOME" 2>/dev/null || true
    log "  Ownership of $CURRENT_HOME settled to $CURRENT_USER."
}

# ── Root-owned file helper ───────────────────────────────────
# Writes a file as root, backing up any existing target first.
# Idempotent: if the target is already byte-identical it is left
# alone and returns 1. Returns 0 if written/changed, 1 if in place.
write_root_file() {
    local src="$1" dest="$2"
    if [[ -e "$dest" ]] && sudo cmp -s "$src" "$dest"; then
        sudo chown root:root "$dest"
        log "  Already in place: $dest"
        return 1
    fi
    backup_file "$dest"
    sudo mkdir -p "$(dirname "$dest")"
    sudo cp -a "$src" "$dest"
    sudo chown root:root "$dest"
    log "  Wrote: $dest"
    return 0
}

# ── Copy only if different (file or tree) ────────────────────
copy_if_changed() {
    local src="$1" dest="$2"
    if [[ -e "$dest" ]] && diff -rq "$src" "$dest" >/dev/null 2>&1; then
        info "  Unchanged: $dest"
        return 1
    fi
    backup_file "$dest"
    mkdir -p "$(dirname "$dest")"
    cp -a "$src" "$dest"
    return 0
}

# ── System state (idempotency markers) ───────────────────────
state_set() {
    local key="$1" val="$2"
    sudo mkdir -p "$DORIS_STATE"
    printf '%s\n' "$val" | sudo tee "$DORIS_STATE/$key" >/dev/null
}
state_get() {
    local key="$1"
    [[ -f "$DORIS_STATE/$key" ]] && cat "$DORIS_STATE/$key" 2>/dev/null || echo ""
}

# ── Connection / network detection ───────────────────────────
# A machine on a trusted LAN has an RFC1918 (or link-local) gateway.
# A machine plugged straight into the ISP's router presents a public
# (or CGNAT) gateway - that connection is not trusted and gets
# encrypted DNS forced on it. Unknown -> assume the worst (direct).
detect_connection() {
    local gw=""
    gw="$(ip route show default 2>/dev/null | awk '/default/{print $3; exit}')"
    if [[ -z "$gw" ]]; then
        gw="$(ip -6 route show default 2>/dev/null | awk '/default/{print $3; exit}')"
    fi
    if [[ -z "$gw" ]]; then
        echo "unknown"
        return 0
    fi
    if [[ "$gw" =~ ^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.) ]] \
       || [[ "$gw" =~ ^fe[89ab][0-9a-f]: ]] \
       || [[ "$gw" =~ ^f[cd][0-9a-f][0-9a-f]: ]]; then
        echo "router"
    else
        echo "direct"
    fi
}

detect_gateway() {
    local gw=""
    gw="$(ip route show default 2>/dev/null | awk '/default/{print $3; exit}')"
    [[ -n "$gw" ]] || gw="$(ip -6 route show default 2>/dev/null | awk '/default/{print $3; exit}')"
    echo "${gw:-}"
}

# Which DNS server the system should be pinned to. router mode pins
# to the LAN router; direct mode pins to stubby (127.0.0.1, DoT out).
doris_dns_server() {
    local mode
    mode="$(state_get mode)"
    if [[ "$mode" == "direct" ]]; then
        echo "127.0.0.1"
    else
        local gw
        gw="$(state_get router-ip)"
        [[ -n "$gw" ]] && echo "$gw" || echo "$DEFAULT_ROUTER_DNS"
    fi
}

# Hard requirement: DORiS cannot install anything without networking.
# Probe a real TCP connect so ICMP-blocked networks still pass.
require_network() {
    local tries=0
    until (exec 3<>/dev/tcp/deb.debian.org/443) 2>/dev/null; do
        exec 3>&- 2>/dev/null || true
        tries=$((tries + 1))
        if [[ $tries -ge 6 ]]; then
            die "No network connectivity (deb.debian.org:443 unreachable)." \
                "DORiS cannot continue without networking. Fix the connection and rerun."
        fi
        sleep 2
    done
    exec 3>&- 2>/dev/null || true
    log "Network OK - deb.debian.org:443 reachable."
}

# ── Wayland detection ────────────────────────────────────────
# The DORiS desktop is X11/openbox. If a Wayland session was chosen
# during the Debian install we warn early (with how to switch) rather
# than pretending everything will just work.
wayland_present() {
    local found=""
    if compgen -G "/usr/share/wayland-sessions/*.desktop" >/dev/null 2>&1; then
        found="yes"
    fi
    if dpkg-query -W -f='${Package} ' gnome-shell sway labwc wayfire kwin-wayland 2>/dev/null | grep -q ' .*\b\(sway\|labwc\|wayfire\|kwin-wayland\)'; then
        found="yes"
    fi
    echo "${found:-no}"
}

# ── Token engine ─────────────────────────────────────────────
# Configs are committed to the kit with `$USER` / `$HOSTNAME` placeholders
# so no identifying info ships (hostnames change between installs - do NOT
# bake them). At restore time the tokens are baked in for the actual login
# user and the box's current hostname. Executable scripts keep runtime
# variables and are skipped.
apply_tokens() {
    local file="$1"
    [[ -f "$file" ]] || return 0
    [[ -x "$file" ]] && return 0
    case "$(file -b --mime-type "$file" 2>/dev/null)" in
        text/*|application/xml|application/json|application/x-empty|inode/x-empty) ;;
        *) return 0 ;;
    esac
    if grep -qE '\$(USER|HOSTNAME)\b' "$file" 2>/dev/null; then
        sed -i -e "s|\$USER\b|$CURRENT_USER|g" \
               -e "s|\$HOSTNAME\b|$(hostname)|g" "$file"
        log "  Tokens replaced in: ${file#$CURRENT_HOME/}"
    fi
}

apply_tokens_tree() {
    local dir="$1"
    [[ -d "$dir" ]] || return 0
    local f
    while IFS= read -r -d '' f; do
        apply_tokens "$f"
    done < <(find "$dir" -type f -print0)
}

# ── Task runner (shared by both runners) ─────────────────────
# run_tasks <dir>
# Reads the caller's globals: DRY_RUN, ASK, ONLY_TASK, SKIP_TASKS.
run_tasks() {
    local dir="$1"

    local TOTAL=0 PASSED=0
    local -a FAILED_LIST=()
    local DRY="${DRY_RUN:-false}" ASK="${ASK:-false}"

    for task in "$dir/"*.sh; do
        [[ -f "$task" ]] || continue
        task_name=$(basename "$task" .sh)
        task_num="$(printf '%d' "$((10#${task_name%%-*}))" 2>/dev/null)" || task_num="${task_name%%-*}"
        only_num="$(printf '%d' "$((10#${ONLY_TASK:-0}))" 2>/dev/null)" || only_num="${ONLY_TASK:-}"

        if [[ -n "$ONLY_TASK" ]] && [[ "$task_num" != "$only_num" ]]; then
            continue
        fi
        for skip in "${SKIP_TASKS[@]}"; do
            skip_num="$(printf '%d' "$((10#${skip:-0}))" 2>/dev/null)" || skip_num="$skip"
            if [[ "$task_num" == "$skip_num" ]]; then
                log "Skipping task $task_name (--skip $skip)"
                continue 2
            fi
        done

        ((TOTAL++))
        if $DRY; then
            desc=$(grep -E '^# [0-9][0-9] ' "$task" | head -1 | sed 's/^# //')
            info "[DRY-RUN] Would run: ${task_name}  $desc"
            continue
        fi

        if $ASK; then
            read -rp "  Run task $task_name? [Y/n] " ans
            case "${ans:-y}" in
                y|Y|"") ;;
                *) log "Skipping task $task_name (user declined)"; continue ;;
            esac
        fi

        # Capture task output live into the log. A failing task must leave a
        # trail - without this, an exit-1 task was invisible in restore.log
        # (the 8440's "system half ran flawlessly" was wrong: 05-tweaks had
        # died on an unbound variable). pipefail (set in the runners) keeps
        # the pipeline's exit code equal to the task's.
        if bash "$task" 2>&1 | tee -a "$LOG_FILE"; then
            log "  TASK $task_name completed successfully."
            ((PASSED++))
        else
            status=$?
            if [[ "$status" -eq 2 ]]; then
                error "  TASK $task_name hit a fatal condition (exit 2). HARD STOP."
                FAILED_LIST+=("$task_name(HARD-STOP)")
                break
            fi
            error "  TASK $task_name FAILED (exit $status)."
            FAILED_LIST+=("$task_name")
        fi
    done

    echo ""
    echo "=============================================="
    echo "  DORiS SUMMARY"
    echo "=============================================="
    echo "  Tasks:   $TOTAL"
    echo "  Passed:  $PASSED"
    if [[ ${#FAILED_LIST[@]} -gt 0 ]]; then
        echo "  Failed:  ${#FAILED_LIST[@]}"
        for f in "${FAILED_LIST[@]}"; do
            echo "    - $f"
        done
    fi
    if [[ ${#FAILED_LIST[@]} -gt 0 ]] && [[ "${FAILED_LIST[-1]}" == *HARD-STOP* ]]; then
        echo ""
        echo "  !! HARD STOP - remaining tasks were NOT run."
        echo "  !! Fix the reported problem and rerun."
    fi
    ERROR_COUNT=$(grep -c '^\[ERROR\]' "$ERROR_FILE" 2>/dev/null || true)
    WARN_COUNT=$(grep -c '^\[WARN\]' "$ERROR_FILE" 2>/dev/null || true)
    echo "  Errors:  ${ERROR_COUNT:-0}"
    echo "  Warnings:${WARN_COUNT:-0}"
    echo ""
    echo "  Log:        $LOG_FILE"
    echo "  Errors:     $ERROR_FILE"

    BACKUP_FILE=$(ls -t "$BACKUP_BASE/"*.tar.gz 2>/dev/null | head -1)
    [[ -n "$BACKUP_FILE" ]] && echo "  Backup:     $BACKUP_FILE"

    [[ ${#FAILED_LIST[@]} -gt 0 ]] && return 1
    return 0
}

list_tasks() {
    local dir="$1"
    for task in "$dir/"*.sh; do
        [[ -f "$task" ]] || continue
        name=$(basename "$task" .sh)
        desc=$(grep -E '^# [0-9][0-9] ' "$task" | head -1 | sed 's/^# //')
        printf '  %s   %s\n' "$name" "$desc"
    done
}
