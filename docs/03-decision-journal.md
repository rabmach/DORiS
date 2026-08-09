# 03 — The Decision Journal

> *Every line in DORiS was a decision, and most of them hurt. This journal is
> the if/then/buts — why we chose what we chose, what we tried instead, and
> what each choice cost.*

## Quick version

| # | decision | one-line why |
|---|----------|--------------|
| D01 | Openbox/X11, not a DE | lightest keyboard-driven desktop that's still fully custom |
| D02 | Stock Debian kernel, any amd64 | xanmod's edge isn't reachable from the kit; agnostic wins |
| D03 | Firefox + Helium | a hardened daily pair, uBlock built into Helium |
| D04 | Bash + vendored kit, no framework | zero deps, offline, transparent, you can read all of it |
| D05 | Two halves: system vs per-user | one machine, many humans |
| D06 | Idempotent + backup-before-touch | re-runs safe, everything reversible |
| D07 | `$USER`/`$HOSTNAME` tokens, never baked names | hostnames change between installs |
| D08 | Everything vendored, offline | the promise is "one stick, one button" |
| D09 | selftest gates every restore | a broken kit must never run |
| D10 | mkwelcome generates docs from the kit | docs can't rot if the kit writes them |
| D11 | nftables deny-out; outbound TCP all-ports | FTPS passive ports are unknowable until TLS |
| D12 | DNS posture auto-detect | trusted LAN vs direct ISP are different worlds |
| D13 | AppArmor complain-first, then enforce | audit before you promise |
| D14 | Browser caches on a ramdisk | history never touches disk |
| D15 | powersave governor + `gov` toggle | performance on demand, silence the rest of the time |
| D16 | journald capped + debsecan weekly | small logs, visible CVEs |
| D17 | Interactive browser assistant, not a watcher | the silent watcher died a silent death (D17 = D17's bug) |
| D18 | Watch until installed, don't assume | ClearURLs UUIDs are not what you think |
| D19 | Per-browser markers | one marker hides a half-set-up browser |
| D20 | Split: DORiS (agnostic) + DORiSP53s (profile) | machine specifics are overlays, not core |

---

## Platform decisions

### D01 — Openbox/X11 over a full desktop environment

**Decision:** Build the desktop on Openbox + X11, configured by hand
(`config/openbox/rc.xml`), with `tint2`-era extras and no compositor-weight
by default.

**Why:** Full DEs (GNOME/KDE/XFCE) trade a pile of moving parts for
convenience. This machine's ethos is control and silence — a tiled,
keyboard-driven rc.xml gives you 90% of the ergonomics with a fraction of
the surface area. It's the difference between configuring a desktop and
owning it.

**Alternatives considered:** i3/sway (real tiling, but a different muscle
memory and a big paradigm jump for the user); GNOME/KDE (convenient, heavy,
rebellious against the keyboard-first goal).

**Compromise / cost:** No fancy effects, no Wayland path, and the desktop
config is a file you edit — not a settings app. That's the point, but it's a
real cost for a less tinker-y user.

**If-then-but:** If you want Wayland — but, DORiS doesn't configure Wayland;
it warns and stays X11.

### D02 — Stock Debian kernel, any amd64

**Decision:** The agnostic kit uses the stock Debian kernel. No xanmod, no
custom kernels.

**Why:** The live box ran xanmod for a while. Its real edge over stock was
`CONFIG_PREEMPT_LAZY` — which is *compile-time*, unreachable from any sysctl
or kit. That was fine for the trial box, but the kit must restore *any* amd64
machine, and a custom kernel is the least portable, most annoying thing to
vendor. Stock wins.

**Alternatives considered:** xanmod in the kit (rejected — arch-specific
binaries, boot risks, the trial proved the gain wasn't worth it); patched
backports (too fiddly).

**Compromise / cost:** We give up a few percent in latency-tolerance on
`i7-8665U`. Fine. The kit runs everywhere.

### D03 — Two browsers: Firefox + Helium

**Decision:** Ship and configure two — Mozilla Firefox (stock, via Mozilla's
own repo) and Helium (a Chromium fork with uBlock Origin built in).

**Why:** One browser is a single point of failure and a single point of
surveillance. A hardened pair covers the two major rendering engines.
Helium's uBlock built-in means the blocking engine survives extension busts
on that side.

**Alternatives considered:** One browser, hardened (simpler, but engine lock-
in); Brave/Vivaldi forks (proprietary-ish, telemetry questions).

**Compromise / cost:** Helium is a niche Chromium fork — some extensions have
no build for it (see D18), and it needs its own repo, its own key handling,
its own quirks. Worth it.

---

## Architecture decisions

### D04 — Bash + vendored kit, no framework

**Decision:** DORiS is bash scripts plus vendored files, not Ansible, not
Nix, not chezmoi.

**Why:** It must run offline from a stick, on a *fresh* machine that has
nothing installed. Bash is guaranteed present. The whole kit is a few hundred
lines you can read end to end in an hour — the exact opposite of a
declarative framework where the real behavior hides behind layers of
abstraction. Also: it's honest about being a *restore system*, not a config
manager. There's no remote state, no inventory, no cloud to reach.

**Alternatives considered:** Ansible (excellent, but needs a control node and
Python everywhere); Nix (powerful, enormous learning curve, brutal on old
hardware); chezmoi/dotdrop (dotfiles-only, we need system state too).

**Compromise / cost:** Less declarative than the fancy stuff. Idempotency and
rollback are *enforced by convention* in `lib.sh` (see D06), not granted by a
tool. That means discipline — which is why selftest (D09) is a hard gate.

### D05 — Two halves: system vs per-user

**Decision:** `restore.sh` (once, root) and `user-setup.sh` (per user, via
`sudo`/`runuser`).

**Why:** One machine, several humans. Firewall, repos, packages — once.
Dotfiles, browsers, welcome — per person. `user-setup.sh --user bob` restores
bob's world without re-running the machine half or clobbering anyone else.

**Alternatives considered:** One monolithic script (simpler, but every user
gets every previous user's leftovers); a system image (great for identical
machines, useless for humans).

**Compromise / cost:** Some install logic lives in both halves (helpers
shared via `lib.sh`). The seam is real; the separation is worth it.

### D06 — Idempotent + backup-before-touch

**Decision:** Every file write goes through `backup_file`/`backup_and_copy`/
`write_root_file`, which keep a `.bak-opencode`-style original, and every
task is re-runnable without harm.

**Why:** Restores get re-run (first login fails? re-run 10-config). Systems
change. A restore should never destroy evidence of what was there. Reversing
a change = restore the backup, rerun.

**Compromise / cost:** A few hundred KB of `.bak-*` files on first restore.
Worth it — this is the difference between an experiment and a reinstall.

### D07 — `$USER` / `$HOSTNAME` tokens, never baked names

**Decision:** Configs ship with `$USER`/`$HOSTNAME` placeholders; `apply_tokens`
bakes them at restore time. `$HOME` is resolved at runtime.

**Why:** The geany config was captured with `bk@debola` hardcoded. Hostnames
change between installs (`debola` → `doris` → ...), users differ. Bake a name
and the kit breaks for everyone else, forever. Tokens cost nothing and fix it
per-user.

**Compromise / cost:** Capturing configs requires scrubbing baked names first
(see `scrub.sh`); occasionally one slips through and 10-config fixes it.

### D08 — Everything vendored, offline

**Decision:** Icons, themes, dotfiles, scripts, hardening configs all live in
the kit. The only online step is `apt` (and the repo adds).

**Why:** The promise is *one stick, one button*. A fresh machine with no
network is still restorable. Also, vendoring pins the config: the kit restores
exactly the version it shipped, not whatever's live today.

**Compromise / cost:** The kit is heavier (icons/themes are real bytes) and
needs discipline to keep current — hence capture/scrub (D09's sibling).

### D09 — selftest gates every restore

**Decision:** `tools/selftest.sh` runs before restore begins (in 00-check).
It parses the package lists, verifies kit files exist, and shell-syntax-checks
every `~/bin` script (by shebang — one script had no shebang, one had
`#! /bin/bash/`). Fail → restore does not start.

**Why:** A broken kit must fail loudly *before* it touches a machine, not
after. The shebang bug, the `grep grep` typo, the divide-by-zero in swap calc
— all caught by selftest before a restore, all real bugs it paid for itself
with. `tools/capture.sh` + `tools/scrub.sh` keep the kit rebuilding itself
from a live box; review the diff, commit.

**Compromise / cost:** A shell-syntax check is not a behavior check. It won't
catch a wrong flag or a wrong file name — but it catches the bulk of kit
decay, and it's free.

### D10 — mkwelcome generates the welcome from the kit

**Decision:** The first-login welcome text is generated by
`tools/mkwelcome.sh` *from the kit itself* — keybinds parsed out of
`rc.xml`, aliases out of `~/.bash_aliases`, timers out of `hardening/`.

**Why:** Hand-written docs rot. The kit changes, the welcome lies, nobody
notices. If the welcome is *derived*, it can't lie.

**Compromise / cost:** The welcome shows real facts, not curated prose — the
format does the thinking.

---

## Security decisions

### D11 — nftables default-deny, outbound TCP all-ports

**Decision:** Firewall is default-deny inbound *and* outbound. Outbound:
loopback, ICMP, DHCP, NTP, plaintext DNS to private ranges only (so any
router's DHCP-pushed DNS works), and **all TCP to any destination**.

**Why the "all-TCP" carve-out:** we *started* with a strict 80/443 host
allowlist. Then came FTPS. The data port is negotiated inside the TLS session
— the firewall can't see it, and allowlisting a high-port range is opening the
door anyway. FTP(S) passive mode is impossible to allowlist from a static
config. Rather than break FTPS, we dropped port filtering for TCP and enforce
trust at the DNS layer instead (NextDNS on the router — filtering works even
though the firewall can't see inside TLS).

**Alternatives considered:** strict allowlist (broken by FTPS); all-open
(no); stateful conntrack FTP helper for plaintext FTP active mode
(loaded — `nf_conntrack_ftp` — but it can't see encrypted PASV).

**Compromise / cost:** Outbound is more open than ideal — any TCP port is
reachable. We accept it because DNS (the last-resort choke point) is
controlled, and inbound stays default-deny. If FTPS ever dies, tighten it
back.

### D12 — DNS posture auto-detect, systemd-resolved removed

**Decision:** `01-connection` detects the network reality: on a trusted LAN
(the router you know, running NextDNS) it pins DNS to the router; on a direct
ISP link it runs `stubby` for encrypted DNS. Home is router-pinned; the
machine on a weird network gets DoT automatically. On the live box,
systemd-resolved was removed outright — router DNS + browser DoH (NextDNS)
replaced it, because RA/DHCPv6-pushed NextDNS IPv6 entries were silently
bypassing the router policy.

**Why:** DNS is the choke point for filtering *and* privacy. But "encrypted
DNS always" is wrong on a trusted LAN — the router's NextDNS filtering is
more valuable than stubby's encryption there. One posture, auto-chosen.

**Alternatives considered:** Always-stubby (breaks router filtering); always-
router (wide open on untrusted links).

**Compromise / cost:** The auto-detect is heuristic (gateway ARP + presence of
a private gateway). It's right in practice; it's documented in the kit.

### D13 — AppArmor complain-first, then enforce

**Decision:** AppArmor ships with profiles in **complain mode** (audit
everything, block nothing), a one-shot reminder timer, and a review workflow
(`aa-logprof`), then `aa-enforce` once the noise is understood.

**Why:** Enforce-without-audit is how you break a working system blind.
Complain-first means every denial is logged before it's enforced — you review
the audit trail, adjust, then flip the switch.

**The footnote that bit us:** on the xanmod kernel the *live* box, AppArmor
wasn't active at all — xanmod's `CONFIG_LSM` omitted it, and the kernel
cmdline had only `root=UUID`. Fix: `lsm=landlock,lockdown,yama,apparmor,bpf`
in `/etc/kernel/cmdline` + `kernel-install add`, regenerating both boot
entries. Stock Debian kernels have AppArmor in LSM by default — the agnostic
kit is fine, but the lesson stands: *verify the security layer is loaded
before you trust it* (that's what `06-verify` checks).

### D14 — Browser caches on a ramdisk

**Decision:** Firefox/Helium cache + history live on a tmpfs (`/dev/shm`),
never on disk.

**Why:** Browsers are the biggest persistent-history leak on a machine. A
reboot wipes it. Cost: a few hundred MB of RAM for a dramatically quieter
disk story.

**Compromise / cost:** Restart the browser = cold cache. Fine — we restart
browsers rarely and the disk silence is the point.

### D15 — powersave governor + `gov` toggle

**Decision:** CPU governor is `powersave` by default, with a one-word toggle
(`gov` → performance, `gov s` → powersave) wired through a systemd service.

**Why:** The machine is a laptop. Most of the time it's idling at 2% — it
should be silent. When it's being pushed, one command flips to performance.
The toggle script preserves the EPP deep-sleep state on the way back.

**Alternatives considered:** `performance` always (hot, loud, wasteful);
`ondemand`/`schedutil` (fine, but the explicit toggle is more predictable).

### D16 — journald capped + debsecan weekly

**Decision:** journald capped at 128M/32M; `debsecan` runs weekly via cron and
pulls CVEs for installed packages.

**Why:** Logs that grow forever are a disk leak nobody notices; CVE awareness
that requires you to remember is CVE awareness that never happens. Capped
logs + a cron CVE scan = small, visible.

**Compromise / cost:** Capped journald loses old logs. Acceptable — that's
what the kernel is for.

---

## Browser assistant decisions

> The browser assistant (launched from the welcome, menu-driven) configures
> Firefox + Helium, installs add-ons, and hardens `about:config`. Three
> decisions below were learned the hard way during the trial installs
> (users `kevin` and `dot`).

### D17 — Interactive assistant, not a silent watcher

**Decision:** The browser setup is an *interactive, menu-driven assistant*
(firefox / helium / both), not a background watcher.

**Why:** The first version was a silent background watcher — and it died a
silent death. Under `set -e`, a `read` from a closed stdin (no TTY) hit EOF
immediately and the watcher exited before doing anything. No error surfaced
until we tried it on `kevin` and the extensions never came. Interactive means
a real TTY, visible feedback, and the user is *there* to click "install."

**Alternatives considered:** fixed background watcher (died on `kevin`);
`policies.json` force-install (rejected — system-wide, hard to remove, feels
like malware to users).

**Compromise / cost:** One click per extension is unavoidable. The user is
shown exactly what to click and the assistant waits.

### D18 — Watch until installed, don't assume

**Decision:** After the user clicks install in the browser, the assistant
*watches the profile dir* for the add-on to appear (as `<id>.xpi`) before
moving on — with a timeout.

**Why:** We originally pre-wired a guessed extension ID for ClearURLs and
treated it as installed. The real build lands under `{74145f27-...}` — not
what we guessed. It "worked" on paper and failed in reality. Watching the
actual profile is the only truthful signal.

**If-then-but:** If the extension never appears within the window, the
assistant says so instead of pretending. The flip side of D17: while Helium's
service is off, web-store fetches silently fail — the assistant warns about
that up front.

### D19 — Per-browser markers

**Decision:** Each browser's setup writes its own marker (and the welcome menu
re-offers whatever's incomplete).

**Why:** A single "browsers done" marker hides a half-set-up browser — done
means *both* browsers are done, and the marker is only written when each one
is actually configured. Per-browser markers + a menu that shows what's left =
no silent gaps.

---

## The split

### D20 — DORiS (agnostic) + DORiSP53s (profile)

**Decision:** The kit was split in two. `~/DORiS` is the machine-agnostic
amd64 restore system (any Debian trixie box: stock kernel, no xanmod/Quadro,
no machine-specific keybinds). `~/DORiSP53s` keeps the original full kit —
the Lenovo P53s specifics (Quadro suspend rules, `bright`/`dim` HDMI-2 keys,
dock layout, P53s wording) — as a profile on top of the same skeleton.

**Why:** The P53s trial taught us everything, but a kit that hardcodes the
P53s is not a restore system for "any amd64 Debian box." Machine specifics
belong in an overlay (per-machine profile), not in the core. Now the core
gets proven on a fresh stock-kernel net-install, and the P53s overlay is
there for when a P53s reinstall happens.

**Alternatives considered:** one kit with conditional blocks (couples the
machines forever); two fully separate kits (drops the shared learning).

**Compromise / cost:** Two repos to keep in sync. But `lib.sh`, task
skeletons, and the browser/welcome machinery are shared — the delta is small
and reviewable.

---

*This journal is a living document. When a decision gets overturned, don't
delete the entry — add the new one, and say why the old one was wrong. That
"why" is the entire point.*
