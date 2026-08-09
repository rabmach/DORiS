#!/usr/bin/env bash
# 2026 machiner opencode
### DORiS - Debian Openbox Restoration Script - 2026
### user-setup.sh - PER-USER mode. Restores dotfiles, ~/bin, ~/.config,
### films.txt, wallpapers, the browsah browser assistant, and installs the first-login
### welcome message for ONE user. Safe to run again for the next user on the
### same machine (everything backs up first, nothing is deleted).
###
### Usage:
###   sudo ./user-setup.sh            # set up the invoking user (SUDO_USER)
###   ./user-setup.sh                 # set up the current user
###   sudo ./user-setup.sh --user bob # set up a specific user
###   ./user-setup.sh --list          # list per-user tasks
###   ./user-setup.sh --dry-run       # show what would run
###   ./user-setup.sh --only 10       # run only one task
###   ./user-setup.sh --skip 12       # skip a task (repeatable)

set -Euo pipefail

export DORIS_DIR
DORIS_DIR="$(cd "$(dirname "$0")" && pwd)"

SKIP_TASKS=()
ONLY_TASK=""
DRY_RUN=false
TARGET_USER=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            cat <<EOF
Usage: $(basename "$0") [OPTIONS]

  --user NAME   Set up a specific user (default: the invoking user)
  --list        List per-user tasks
  --dry-run     Show what would be done without executing
  --only NUM    Run only a single task
  --skip NUM    Skip a task (can be used multiple times)

Per-user tasks:
EOF
            ;&
        --list)
            export DORIS_DIR
            source "$DORIS_DIR/lib.sh"
            list_tasks "$DORIS_USER_DIR"
            exit 0
            ;;
        --user) shift; TARGET_USER="$1"; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --only) shift; ONLY_TASK="$1"; shift ;;
        --skip) shift; SKIP_TASKS+=("$1"); shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Pin the target user before sourcing lib.sh so CURRENT_USER resolves.
if [[ -n "$TARGET_USER" ]]; then
    export SUDO_USER="$TARGET_USER"
elif [[ -n "${SUDO_USER:-}" ]]; then
    export SUDO_USER="$SUDO_USER"
fi

source "$DORIS_DIR/lib.sh"

if [[ "$(id -u)" -eq 0 && "$CURRENT_USER" == "root" ]]; then
    die "No target user. Run as your user, or use:  sudo $0 --user <name>"
fi

cat << "EOF"

   ____                          ____    ____  ___
  / __ \___  _   _  ____  ____  / __ \  / __ )/   |
 / / / / _ \| | | |/ __ \| __ \/ / / / / __  / /| |
/ /_/ / (_) | |_| | (__) |  __/ /_/ / / /_/ / ___ |
\____/\___/ \__,_|\____/|_|    \____/ /_____/_/  |_|

  DORiS - per-user setup
=====================================================
EOF

log "Starting DORiS per-user setup..."
log "User: $CURRENT_USER  Home: $CURRENT_HOME  Date: $(date)"
[[ "$DRY_RUN" == true ]] && info "DRY RUN MODE - No changes will be made"
[[ "$ONLY_TASK" != "" ]] && info "Only running task: $ONLY_TASK"

if ! run_tasks "$DORIS_USER_DIR"; then
    exit 1
fi

# After a successful run the welcome text is available; show it now so the
# user sees the credentials reminder while the restore is fresh in their head.
WELCOME="$CURRENT_HOME/.config/doris/welcome.txt"
if ! $DRY_RUN && [[ -f "$WELCOME" ]]; then
    echo ""
    echo "=============================================="
    cat "$WELCOME"
    echo "=============================================="
fi

exit 0
