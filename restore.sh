#!/usr/bin/env bash
# 2026 machiner opencode
### DORiS - Debian Openbox Restoration Script - 2026
### restore.sh - SYSTEM mode. Runs the once-per-machine parts:
###   prerequisites, connection/DNS strategy, repos, packages,
###   system-wide icons+themes, hardening (firewall/DNS/AppArmor),
###   and a final verification pass.
###
### Run as root:
###   sudo ./restore.sh
###
### Per-user config (dotfiles, bin, welcome message) is restored by:
###   ./user-setup.sh
###
### Usage:
###   sudo ./restore.sh            # full system restore (non-interactive)
###   sudo ./restore.sh --help     # help
###   sudo ./restore.sh --list     # list system tasks
###   sudo ./restore.sh --skip 05  # skip a task (repeatable)
###   sudo ./restore.sh --only 03  # run only one task
###   sudo ./restore.sh --dry-run  # show what would run, change nothing
###   sudo ./restore.sh --ask      # confirm each task
###   sudo ./restore.sh --extras   # also install packages/extras.list
###
### Environment:
###   DORIS_ASK=1     same as --ask
###   DORIS_EXTRAS=1  same as --extras
###   DNS_SERVER=IP   fallback LAN router DNS if gateway undetectable
###
### The system must have working networking before this runs; the
### script refuses to continue otherwise.

set -Euo pipefail

export DORIS_DIR
DORIS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DORIS_DIR/lib.sh"

SKIP_TASKS=()
ONLY_TASK=""
DRY_RUN=false
ASK=false
EXTRAS=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --help         Show this help message
  --list         List available tasks
  --skip NUM     Skip a task (can be used multiple times)
  --only NUM     Run only a single task
  --dry-run      Show what would be done without executing
  --ask          Confirm each task before running
  --extras       Also install everything in packages/extras.list

Environment:
  DORIS_ASK=1     Same as --ask
  DORIS_EXTRAS=1  Same as --extras
  DNS_SERVER=IP   Fallback LAN router DNS (default 192.168.1.1)

System tasks:
EOF
    list_tasks "$DORIS_SYSTEM_DIR"
    cat <<EOF

After this, run per-user setup:
  ./user-setup.sh
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h) usage ;;
        --list) usage ;;
        --skip) shift; SKIP_TASKS+=("$1"); shift ;;
        --only) shift; ONLY_TASK="$1"; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --ask) ASK=true; shift ;;
        --extras) EXTRAS=true; shift ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

[[ "${DORIS_ASK:-0}" == "1" ]] && ASK=true
[[ "${DORIS_EXTRAS:-0}" == "1" ]] && EXTRAS=true

export ASK EXTRAS

cat << "EOF"

  Debian Openbox Restoration Script - DORiS  (SYSTEM mode)
=====================================================
EOF

# Fresh logs. Only touch them when we are actually going to run.
rm -f "$ERROR_FILE"
: > "$LOG_FILE"
: > "$ERROR_FILE"

# Hand the kit's state files back to the target user. A subsequent per-user
# run WITHOUT sudo appends to these logs and creates backups under backups/;
# if a root restore leaves them root-owned, that run floods with "Permission
# denied" on every log line and every backup (the 8440's first re-test).
if [[ -n "$CURRENT_USER" && "$CURRENT_USER" != "root" ]]; then
    chown "$CURRENT_USER" "$LOG_FILE" "$ERROR_FILE" 2>/dev/null || true
    mkdir -p "$BACKUP_BASE" 2>/dev/null || true
    chown "$CURRENT_USER" "$BACKUP_BASE" 2>/dev/null || true
fi

log "Starting DORiS system restoration..."
log "User: $CURRENT_USER  Home: $CURRENT_HOME  Date: $(date)"
[[ "$DRY_RUN" == true ]] && info "DRY RUN MODE - No changes will be made"
[[ "$ASK" == true ]]     && info "INTERACTIVE MODE - prompts enabled"
[[ "$EXTRAS" == true ]]  && info "EXTRAS - installing packages/extras.list too"

if ! run_tasks "$DORIS_SYSTEM_DIR"; then
    exit 1
fi

exit 0
