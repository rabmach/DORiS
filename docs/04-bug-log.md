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
| **005** | plain `./user-setup.sh`: "Permission denied" flood | kit logs + backups/ left root-owned by the sudo system half | fixed |
| **006** | welcome skipped straight into the browser menu | stale key in the tty queue answered "press any key" (or empty welcome.txt skipped the gate) | fixed |
| **007** | win+f never opened thunar, silently | the per-user half called `sudo update-alternatives` (needs a password on fresh installs) | fixed |
| **008** | browser assistant: "profile detected" before any first-run happened | `profiles.ini` is written at browser spawn, so the wait loop matched it immediately | fixed |
| **009** | fresh restore: `auditd failed to start`, 06-verify "auditd is active" FAILED | `write_root_file` used `cp -a`, which preserved the git-checkout *owner* onto `/etc` files → auditd refuses non-root-owned config; `loginfetch` became a root-run binary owned by the checkout user (privesc smell) | fixed |

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

## BUG-005 — plain-user `user-setup.sh`: the kit's own state was root-owned

**Symptom (2026-08-13, the 8440's re-test with the fixed kit):** the system
half (`sudo ./restore.sh`) ran clean, then the documented plain run
`./user-setup.sh` flooded the terminal with "Permission denied" — even though
the home itself was owned correctly.

**Root cause:** `restore.sh` truncates `restore.log`/`restore-errors.log`
**as root** and the system tasks create `backups/` **as root**, all inside the
kit directory. A subsequent *plain-user* per-user run then could not write any
of them: every `log()` line is `tee -a restore.log` (`lib.sh:44`) → "tee:
Permission denied" on every message, and `backup_and_copy` → `mkdir
backups/<ts>/…` → "Permission denied" on every backup. `settle_ownership` is a
no-op when not root, so it couldn't help. The two documented invocations
(`./user-setup.sh` in the VM walkthrough, `sudo ./user-setup.sh` in the table)
were even inconsistent — this bug is why.

**Fix (two layers):**
- `restore.sh`: after truncating the logs, `chown` `restore.log`,
  `restore-errors.log` and the `backups/` parent to the invoking user, so a
  plain per-user run finds its own state.
- `user-setup.sh`: when run without root and the kit's log isn't writable,
  fall back to `~/.doris-user-setup.log` instead of flooding stderr; and if
  the home itself isn't writable, die with one clear "run once with sudo"
  message instead of a wall of `mkdir` errors.

**Cost / note:** chowning the kit's state files to the user is safe (logs and
backups only — never the scripts themselves, which a user-owned kit already
owns). On a box already mid-restore, one
`sudo chown -R user:user ~/DORiS` heals kit state retroactively.

---

## BUG-006 — the welcome skipped straight into the browser menu

**Symptom (2026-08-13, the 8440's re-test):** on first login the welcome text
was gone and `doris-welcome` landed directly in the browser-setup menu — no
"press any key" hand-off, even though the same welcome had worked on the
previous install.

**Root cause (two layers):**
1. **Stale-key race.** `doris-welcome` runs in a terminal that Openbox launches
   at login. Keys the user types while the desktop/terminal is still starting
   sit in the tty input queue; when the script finally runs `read -n1`, it
   answers the "press any key" gate *instantly* with that old key — the queue
   doesn't care what the screen showed first. It "worked last time" because a
   race only fires when you hit the timing.
2. **Empty welcome text.** If `welcome.txt` came out empty, `[[ -s "$WELCOME" ]]`
   skipped the gate **entirely** — there was no hand-off to miss at all.

**Fix:**
- New `drain_input()` in `doris-welcome` — a non-blocking `read` loop that
  empties the tty queue *before* every interactive read, so only keys typed
  after the prompt is visible count.
- The gate now always runs when the marker is absent, showing a placeholder
  line instead of silently diving into the browser menu if `welcome.txt` is
  empty.

**Cost / note:** draining can't distinguish "typed during startup" from
"typed after the prompt" — it just resets the window to zero at each prompt.
That's the honest fix for a fundamentally racy interaction.

---

## BUG-007 — win+f never opened thunar, silently

**Symptom (2026-08-13, the 8440):** the `win+f` → thunar tweak was still not
applied after a plain `./user-setup.sh`, and no error appeared in
`restore-errors.log` (the plain run couldn't write the root-owned errors file
either — see BUG-005).

**Root cause:** task 10 ran `sudo update-alternatives --set x-file-manager
/usr/bin/thunar`. On a fresh net-install sudo prompts for a **password**; a
plain user half has no business calling it, the prompt is easy to miss, and
the failure was swallowed.

**Fix:** the system-wide alternative moved to task 04 (`04-assets.sh`) where
the system half is already root. The per-user half now only sets the
per-user `inode/directory` handler (`xdg-mime`, no sudo). Per-user setup no
longer needs root for this — the architectural rule: *system-wide → system
half; user-level → user half.*

**Cost / note:** a machine whose system half hasn't run (or re-ran) won't have
the alternative — that's correct: the user half shouldn't be doing root work.

---

## BUG-008 — browser assistant "detected" a profile that didn't exist yet

**Symptom (2026-08-13, the 8440):** in the browser assistant, hitting "1) Set
up Firefox" launched Firefox and ~1 second later declared *"Firefox profile
detected"* — before the user had gone through the first-run wizard. It then
ran the config and opened the first extension page, which landed
simultaneously with Firefox's own first-run setup.

**Root cause:** `ensure_profile`'s wait loop checked `pgrep` first, then fell
through to "profile exists?" — and `FF_GLOB` matched **`profiles.ini`**, which
Firefox writes at *spawn time*, before the profile is initialized. On the
first loop iteration the just-spawned process wasn't visible to `pgrep` yet,
so the `elif` matched instantly. `profiles.ini` was never a "real profile"
signal.

**Fix (browsers/post-login.sh):**
- `FF_GLOB` now matches the initialized profile's **`prefs.js`** (written only
  when the profile is actually created), not `profiles.ini`.
- The wait loop only accepts "profile detected" after the browser has been
  **seen running** (`seen=1`) **and** is now closed — so a spurious glob match
  during the spawn window can't fire early.

**Cost / note:** a profile dump (from the user's live box) contains `prefs.js`,
so restore-dump flows still take the "profile exists" shortcut as designed.

---

## BUG-009 — `cp -a` in write_root_file copied the checkout owner onto /etc

**Symptom (2026-08-13, the 8440):** `05-hardening` logged `auditd failed to
start.`, and 06-verify failed its `auditd is active` check (the restore's only
error). `journalctl -u auditd` said it plainly: *`/etc/audit/auditd.conf isn't
owned by root`*.

**Root cause:** `write_root_file()` in lib.sh copied kit files into `/etc`
with `sudo cp -a`. `cp -a` = `--preserve=all`, which keeps the **source
ownership** — and the source lives in `~/DORiS`, checked out by the *user*.
So every system file the kit dropped in place (`auditd.conf`, `nftables.conf`,
AppArmor profiles, sysctl drop-ins, cron, stubby, systemd units, and
`/usr/bin/loginfetch`) was owned by the checkout user, not root.

Auditd is the one daemon that *enforces* root ownership of its config — it
aborts on any other owner (a deliberate anti-privesc measure). That explains
the whole arc: mid-restore the daemon was already running from package install
(old root-owned config still in memory) so `systemctl enable --now` reported
success; after reboot auditd read the freshly-copied user-owned config and
refused. The earlier "audit.service failing at boot" report was blamed on the
dying drive — it was this bug all along.

**Fix (lib.sh):** after the copy, `sudo chown root:root "$dest"`. One line in
the one choke-point that writes system files.

**Cost / note:** forcing root:root is correct for every `write_root_file`
caller (they're all system paths). Beyond the auditd failure this closed a
real security smell: `loginfetch` runs as **root** at every tty login, and a
root-run `/usr/bin` binary owned by a normal user is a trivial local
privilege-escalation vector. The user half was already fine (it copies into
`~`, user-owned anyway).

---

*Filed 2026-08-13 from the first machine-agnostic fresh-install test (the
8440). The net-install that found these was worth it: this is the only test
that counts.*
