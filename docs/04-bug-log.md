# 04 — The Bug Log

> *Every bug that survives to a real machine gets an entry here: the symptom,
> the root cause, and the fix. Not deleted when fixed — the "why" is the whole
> point, and a fresh net-install is the only test that counts.*

## Quick version

| bug | symptom | root cause | status |
|-----|---------|------------|--------|
| **001** | user-setup: `mkdir: Permission denied` all over a fresh install; thunar/win+f tweak silently missing | home ownership settled only at end-of-task; run-as-user steps ran too early | fixed |
| **002** | system half: `05-tweaks FAILED (exit 1)`, loginfetch banner never installed | undefined `$HARDENING` → `set -u` abort | fixed |
| **003** | failing tasks left no trace in the log | `run_tasks` never captured task output | fixed |
| **004** | every fresh restore: "Mozilla key fingerprint MISMATCH" | kit pinned an outdated Mozilla key fingerprint | fixed |

---

## BUG-001 — user-setup home ownership: `mkdir: Permission denied` everywhere

**Symptom (reported from a fresh net-install, 2026-08-13, the 8440):**
`user-setup.sh` spewed `mkdir: cannot create directory … Permission denied`
errors across the run. A manual `sudo chown -R machiner:machiner /home/machiner`
was required before a re-run would work. And after that successful re-run, the
`win+f` → thunar **x-file-manager tweak was still not done** — with an error
message that never surfaced during the restore.

**Root cause (two layers):**
1. `user-setup.sh` performs file operations as the runner's UID. Invoked via
   `sudo`, everything it copies into `$CURRENT_HOME` lands **root-owned**, and
   ownership was only corrected by `own_as_user` at the **end** of each task.
2. In `10-config.sh`, the run-as-user step
   (`runuser -u "$CURRENT_USER" -- xdg-mime default thunar.desktop inode/directory`)
   executes **before** that end-of-task chown — so it wrote into a root-owned
   `~/.config` and failed. The failure was then swallowed by
   `2>/dev/null || true`, so the tweak silently never applied.
   Invoked as the plain user against a root-owned home, the same ordering made
   every `ensure_dir`/`mkdir` fail.

**Fix:**
- New `settle_ownership()` in `lib.sh` — when running as root, `chown -R
  $CURRENT_HOME` to `$CURRENT_USER` **at the very start of `user-setup.sh`**,
  before any task runs. This mirrors the manual chown that fixed the machine,
  and makes run-as-user steps work regardless of how the runner was invoked
  (or what a previous run left behind).
- `10-config.sh` now logs file-manager step failures instead of swallowing
  them (`warn` + a re-run hint), so a future regression is visible.

**Cost / note:** a whole-home `chown -R` at the start of a sudo-run is cheap
(ownership only, no data) and only ever touches the target user's own home.

---

## BUG-002 — `05-tweaks.sh`: unbound variable `$HARDENING`

**Symptom:** `TASK 05-tweaks FAILED (exit 1)` during the system restore; the
loginfetch `/etc/issue` banner and getty override never installed. The failure
was invisible (see BUG-003), so the restore looked flawless.

**Root cause:** `05-tweaks.sh` referenced `$HARDENING`, but that variable is a
plain assignment *inside `05-hardening.sh` only*. Every task runs as its own
`bash` process, so in `05-tweaks` the variable is undefined — and with
`set -Euo pipefail`, an unbound variable aborts the task at the first
reference. `$HARDEN_DIR` is the variable `lib.sh` actually exports.

**Fix:** `$HARDENING` → `$HARDEN_DIR` in `05-tweaks.sh`.

**How to prevent the class:** `selftest.sh` does `bash -n` (syntax) only —
it cannot catch runtime `set -u` landmines. Recommendation: run `shellcheck`
over `tasks/` before a restore (not installed on the reference box; adding it
is a one-apt change to `selftest.sh`).

---

## BUG-003 — the runner hid task failures

**Symptom:** a task exiting non-zero left nothing in `restore.log`; the 8440's
"system half ran flawlessly" was wrong — `05-tweaks` had died. Failures were
terminal-only and died with the session.

**Root cause:** `run_tasks()` ran `bash "$task"` without capturing stdout or
stderr. Task detail never reached the log.

**Fix:** tasks now run as `bash "$task" 2>&1 | tee -a "$LOG_FILE"` —
`pipefail` in the runners preserves the task's exit code, and all task output
lands in the log live. A future failing task leaves a trail you can email.

---

## BUG-004 — stale Mozilla repo key fingerprint

**Symptom:** every fresh restore warned
`Mozilla key fingerprint MISMATCH` (expected `…5CE3537168ED1`, got
`…5CE6DC6315A3`) and installed the key anyway.

**Root cause:** the kit pinned an outdated Mozilla signing key. Mozilla's
documented fingerprint for `packages.mozilla.org` is
`35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3` — the "got" value was correct all
along, the pin was the lie.

**Fix:** updated the pinned fingerprint in `02-repos.sh`.

**Note:** the "install anyway on mismatch" behavior is deliberate — a flaky
keyserver must not brick a whole restore (02-repos documents this). With the
pin corrected, a real mismatch still warns loudly.

---

*Filed 2026-08-13 from the first machine-agnostic fresh-install test (the
8440). The net-install that found these was worth it: this is the only test
that counts.*
