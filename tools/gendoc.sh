#!/usr/bin/env bash
# 2026 machiner opencode
### part of the DORiS suite of goodness - debian openbox restoration script(s) - 2026
### gendoc.sh - build the doc (what it is) from the kit's own announce() calls.
###
### The restore speaks (lib.sh announce) and this tool writes it down: the doc
### is the restore's narration, extracted. One source of truth - the docs can't
### drift from reality because the docs ARE the restore.
###
###   tools/gendoc.sh [OUT]    # default: $CURRENT_HOME/what-it-is.md
###
### Called at the end of BOTH runners. Regeneration is the point - the doc is
### a where-it's-at: it stays current for whoever just ran, and every user who
### gets the box gets it only through user-setup.sh, so every user gets a full
### qualified copy of their own. Announced ONLY at the end of user-setup (the
### true Done moment); the system half's last word stays ./user-setup.sh.
###
### Overwrite by design. The source text lives in the kit, so nothing is lost.

set -Euo pipefail

export DORIS_DIR
DORIS_DIR="${DORIS_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
source "$DORIS_DIR/lib.sh"

OUT="${1:-$CURRENT_HOME/what-it-is.md}"

# --- chapter title from the task heading comment ---
# Wrapped headings are cut clean: an unbalanced paren drops (the wrap
# continues on the next comment line), and a heading that keeps going
# mid-sentence stops at its first period. 00/02/04/05 keep their full
# parentheticals because they balance.
doc_title() {
    local t="$1" prev
    while [[ "$(tr -cd '(' <<<"$t" | wc -c)" -ne "$(tr -cd ')' <<<"$t" | wc -c)" ]]; do
        prev="$t"
        t="${t%(*}"
        t="${t% }"
        [[ "$t" == "$prev" ]] && break
    done
    t="${t%%. *}"
    echo "$t"
}

# --- the kit's tasks, in order (system first, then user) ---
TASKS=()
while IFS= read -r -d '' task; do
    TASKS+=("$task")
done < <(find "$DORIS_SYSTEM_DIR" "$DORIS_USER_DIR" -name '*.sh' -print0 2>/dev/null | sort -z)

# --- version: honest about what a dump-deployed copy can't know ---
VER="$(git -C "$DORIS_DIR" describe --tags 2>/dev/null || echo "unversioned copy")"

# --- DNS mode: chapter 04 means something different each way ---
MODE="$(state_get mode)"
case "$MODE" in
    router) MODE_LINE="machine knows the router (DNS mode: router)" ;;
    direct) MODE_LINE="on the open road (DNS mode: direct, encrypted)" ;;
    *)      MODE_LINE="DNS mode: unknown" ;;
esac

# --- title page + preface (machiner's philosophy, spoken at the reader) ---
{
    echo "# what it is"
    echo ""
    echo "*for ${CURRENT_USER} at $(hostname) - $(date '+%b %-d %Y') · ${MODE_LINE} · DORiS ${VER}*"
    cat <<'PREFACE'

## whaddup, new-guy

This is your digs - a machine someone built on purpose. Here's why the
things, what they do, why I like them, and how they tie into other things.
Read it or don't; the box works either way. But if you're the kind who
wants to know what's going on - this is what's going on.

Nothing in here needs your courage. Everything named in this doc is
already handled: the box came that way, it stays that way, and you can't
break it by reading. Curiosity is the only requirement.

Go ahead and try things. Humans learn by falling forward - that's not a
metaphor, it's how every good linux user you'll ever meet got that way.

- machiner, via DORiS
PREFACE
    # the creed: docs/creed.md - the why (the education layer). Theme text,
    # no behavioral claims, so it can't drift from the restore. Rendered
    # verbatim, machiner's voice, machiner's edits.
    if [[ -f "$DORIS_DIR/docs/creed.md" ]]; then
        echo ""
        cat "$DORIS_DIR/docs/creed.md"
        echo ""
    fi
    echo ""
    echo "----"
    echo ""

    for task in "${TASKS[@]}"; do
        [[ -f "$task" ]] || continue
        name="$(basename "$task" .sh)"
        desc="$(grep -E '^# [0-9][0-9] ' "$task" | head -1 | sed 's/^# //')"
        desc="$(doc_title "$desc")"
        [[ -n "$desc" ]] || desc="$name"
        echo ""
        echo "## $desc"
        echo ""
        has=0
        while IFS= read -r line; do
            raw="$line"
            line="${line#announce }"
            title="${line:1}"; title="${title%%\"*}"
            rest="${line#\"*\" }"
            [[ "$rest" == "$raw" ]] && continue   # malformed - selftest catches it
            body="${rest:1}"; body="${body%\"}"
            echo "**$title**"
            echo ""
            echo "$body"
            echo ""
            has=1
        done < <(grep '^announce "' "$task" 2>/dev/null)
        if [[ "$has" == 0 ]]; then
            echo "*(this task hasn't learned to speak yet)*"
            echo ""
        fi
    done
} > "$OUT" 2>>"$ERROR_FILE" || { warn "Doc generation failed: $OUT"; exit 0; }

[[ "$(id -u)" -eq 0 && -n "$CURRENT_USER" && "$CURRENT_USER" != "root" ]] \
    && chown "${CURRENT_USER}:${CURRENT_USER}" "$OUT" 2>/dev/null || true

info "The doc is current: $OUT"
