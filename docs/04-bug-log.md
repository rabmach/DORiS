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
| **010** | fresh-profile browser setup hung: Firefox launched, first-run done, browser closed, assistant never continued | Debian's `firefox` is a launcher ELF that `execv()`s `firefox-bin`; the watcher's `pgrep -x firefox` can never match, so the profile was never accepted and the loop ran its full 20-min timeout | fixed |

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

---

## BUG-010 — browser wait loop never matched a running Firefox

**Symptom (2026-08-13, live-box test user `doris`):** the browser assistant
launched Firefox for its first run, the first-run wizard was completed, the
browser was closed — and the assistant never continued. No message, just a
hang. Re-launching and closing Firefox again didn't help. Ctrl-C killed it.
On the next login the menu option was picked again and it sailed through —
because by then the profile already existed, so the wait loop was never
entered.

**Root cause:** Debian's firefox package ships a tiny launcher ELF
(`/usr/lib/firefox/firefox`, the thing `/usr/bin/firefox` symlinks to) that
`execv()`s the real binary `/usr/lib/firefox/firefox-bin`. The running
process is therefore *named* `firefox-bin`, never `firefox`. The watcher
looped on `pgrep -x firefox`, which can never match, so `seen` stayed 0 and
the `elif (( seen )) && any_glob_ready` exit condition could never fire. The
loop then ran its full 1200-second budget and timed out — the "hang".

**Fix (browsers/post-login.sh):** a `browser_alive()` helper that matches
`firefox`, `firefox-bin`, and `firefox-esr` (the launcher execs the bin; ESR
ships that name directly; the plain name is what the wrapper is called in
some installs). It is now used for every process check: the first-run wait
loop, the already-running branch, `clear_stale_locks`, and
configure-firefox.sh's "close it first" guard. The stale-lock deletion
otherwise had the *reverse* danger: it would delete Firefox's SingletonLock
files while Firefox was actually running.

**Cost / note:** helium is unaffected — its main process really is named
`helium`. Verified live: `browser_alive firefox` returns true while
firefox-bin runs, false after close.

*Filed 2026-08-13 from a first-run walk-through of the browser assistant on
a live test user — the closest thing to a fresh install short of one.*

*Filed 2026-08-13 from the first machine-agnostic fresh-install test (the
8440). The net-install that found these was worth it: this is the only test
that counts.*

## BUG-011 — `x-file-manager` / `x-text-editor` never set on a fresh netinst

**Symptom (2026-08-16, first wiped-drive fresh net-install, the P53s):**
restore.sh completed with exactly one warning —
`[WARN] update-alternatives x-file-manager failed (is thunar installed?)`.
thunar *was* installed; the `--set` just never applied. `x-text-editor`
wasn't attempted at all, so it stayed unset too. The user had to set both
alternatives by hand afterwards.

**Root cause:** `update-alternatives --set <name> <path>` fails with
`error: no alternatives for <name>` (rc=2) when the *group* does not yet
exist. On a fresh netinst nothing has registered the `x-file-manager` or
`x-text-editor` groups — Debian only populates them when a desktop /
editor package lands, and the kit's `--set` cannot create a group.
(BUG-007's move of these tweaks into the system half was correct; the
`--set` mechanism itself was the blind spot.)

**Fix (tasks/system/04-assets.sh):** try `--set` first; on failure fall
back to `update-alternatives --install <link> <name> <path> 30`, which
creates the group, then `--set` again to force our choice. Both defaults
are now set by the system half:
  `x-file-manager -> /usr/bin/thunar` (priority 30)
  `x-text-editor  -> /usr/bin/subl`   (sublime-text, priority 30)
Verified the fallback path end-to-end on the fresh box with a throwaway
group (`--set` rc=2 → `--install` creates → `--set` succeeds → removed).

**Cost / note:** `--install` at priority 30 wins over any later DE that
registers a competing default at a lower priority; the trailing `--set`
makes the choice explicit anyway. The per-user half still only sets the
inode/directory xdg-mime handler (no sudo) per BUG-007.

*Filed 2026-08-16 from the first clean wiped-drive net-install — the P53s
dogfood. Proof is in the restoration.*

## BUG-012 — doris-welcome fires at EVERY login (self-disable never existed)

**Symptom (2026-08-31, after weeks of daily use):** the first-login welcome
pops up at every subsequent login; the user had to comment the autostart
line out by hand to stop it.

**Root cause:** `bin/doris-welcome` wrote a `welcome-shown` marker and the
autostart comment said "shows once, then self-disables" — but nothing
actually *checked* the marker before acting. Launcher mode unconditionally
spawned a terminal on every login; `--run` mode showed the welcome whenever
the marker was missing (which it stays if the window is closed without
pressing a key) and, even with the marker present, still opened a window
demanding a keypress just to print "Done. Have a nice day."

**Fix (bin/doris-welcome):** early `exit 0` on marker in BOTH modes —
the launcher exits before opening any terminal, and `--run` exits before
printing anything. Also fixed a `a || b && c` precedence bug in the yad
branch (replaced with a real `if`). The autostart line now stays in place
permanently and is genuinely inert after the first show: no file to
re-enable, nothing to comment out, a fresh user still gets the one-time
welcome. To see the welcome again by choice:
`rm ~/.config/doris/welcome-shown`.

*Filed 2026-08-31 from weeks of real daily driving — the bugs that survive
weeks are the ones no test harness thinks to look for.*

## BUG-013 — apparmor-review suggested commands that cannot work

**Symptom (2026-08-31, same weeks-long use):** the review reminder fired;
running the command it suggested, `aa-logprof -p helium-bin`, errored out.

**Root cause (two bugs in one):**
  1. `aa-logprof` has no `-p`/profile-selection flag — it walks every
     profile found in the audit log and you (S)kip the ones you don't
     want. The kit invented a flag and printed it in three places
     (bin/apparmor-review header + notification, the sublime-text profile
     header).
  2. The guidance said to enforce `helium-bin` — but helium-bin ships as a
     6-line `flags=(default_allow)` + `userns` stub attached to
     /opt/helium/helium. Enforcing it on a live box (2026-08-31) made
     Helium un-launchable; the browser needs real rules (SUID
     chrome-sandbox, namespace dance) that a stub doesn't carry.
     The user had to flip it back to complain.

**Fix:** all suggested commands now say plain `sudo aa-logprof` ((S)kip
what you don't want); the enforce step says `sublime-text` ONLY and
documents the helium-bin keep-in-complain rule with the reason. Same
wording propagated to tools/mkwelcome.sh (welcome text) and README.
Enforcing helium-bin returns to the roadmap only when a real profile is
written from actual aa-logprof output.

*Filed 2026-08-31, same dogfooding round as BUG-012.*

### BUG-013 addendum — enforce experiment (2026-08-31, live box, fully reversible)

Method: `aa-enforce helium-bin` → launch `/opt/helium/helium` → observe →
`aa-complain` back. Two-direction proof.

| mode | result |
|------|--------|
| enforce | dies within 8 s. stderr: `error while loading shared libraries: libdl.so.2: cannot open shared object file: Permission denied` |
| complain | launches fine (8 s survival check), test instance closed after |

Two findings worth keeping:

1. **No AVC records exist for the enforce failure.** The kernel never
   "killed" anything — ld.so's `open()` of libdl.so.2 returned EACCES and
   the loader exited cleanly. A silent clean exit, not a mediation kill:
   audit-only debugging would have shown *nothing* here. When a confined
   process "won't launch", read the process's own stderr, not just the
   audit log.
2. **Mechanism:** the 6-line stub (`flags=(default_allow)` + `userns` under
   `abi <abi/4.0>`) does not carry what the early library-load path needs
   (the execute-mmap `m` permission on shared libs in this kernel's feature
   set is the prime suspect). `default_allow` is not "a working browser
   profile"; it's a template. The cure stays the same: build a real
   profile from `aa-logprof` output before any enforcement.

Box returned to complain; no stray processes; live state identical to
pre-experiment.
