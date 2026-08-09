# 00 — The Big Picture

> *The quick version is the first section. The rest is how it's actually put
> together — the architecture, exploded.*

## Quick version

DORiS is a desktop restoration system for any amd64 Debian trixie machine. One
kit, fully vendored and offline, recreates a hardened, keyboard-driven
Openbox/X11 desktop from a fresh net-install — plus a security profile, two
configured browsers, and a first-login welcome that walks you through the
one-time bits. System setup runs once (`sudo ./restore.sh`); per-user setup
runs for every human who logs in (`./user-setup.sh`, or `--user bob`).

Everything is idempotent, backs up before it touches a file, and verifies
itself at the end. The kit is machine-agnostic: vendor firmware is
auto-detected, and machine-specific tweaks live in optional overlays, not in
the core.

| | |
|---|---|
| **Target** | any amd64 Debian trixie box, offline except `apt` |
| **Desktop** | Openbox / X11 — lightweight, keyboard-driven |
| **Two halves** | `restore.sh` (system, once) · `user-setup.sh` (per-user, every user) |
| **Browsers** | Firefox + Helium, configured and hardened by an interactive assistant |
| **Security** | nftables default-deny, DNS posture auto-detect, AppArmor, debsecan |
| **Guarantee** | idempotent, reversible (backups), self-verifying (`06-verify`, `selftest.sh`) |

## The promise

One stick. One button. Offline. Hardened, configured, bespoke desktop. ka-BAM.

The point of DORiS is that a fresh machine comes out the other side *home*:
every keybind you expect, every alias, the firewall that means it, two
browsers already set up the way you like them. And it does it again for the
next user, and the next machine, identically.

## The two halves

| half | script | when | audience |
|------|--------|------|----------|
| **system** | `sudo ./restore.sh` | once per machine | root |
| **per-user** | `sudo ./user-setup.sh [--user bob]` | once per user | any human on that machine |

The split exists because one machine often has several humans. The system
half does everything a machine needs once (repos, packages, firewall, DNS
strategy, AppArmor). The per-user half does everything a *person* needs
(dotfiles, `~/bin`, wallpapers, browser setup, welcome). Run the system half
once, then the per-user half for each user.

## How a restore flows

```
  Debian trixie net-install (root password, standard system utilities)
        │
        ▼
  root: adduser <you> + sudo + reboot                     ~2 min
        │
        ▼
  get the kit:  git clone  OR  a USB/backup stick         offline, works
        │
        ▼
  sudo ./restore.sh        (system half)                  ~10-20 min
   ├─ 00-check      root? amd64? network? kit self-test   (dies on no-net)
   ├─ 01-connection router vs direct-ISP → DNS mode        (auto)
   ├─ 02-repos      Mozilla, Helium, Sublime, GitHub Desktop
   ├─ 03-packages   core.list + Intel/AMD microcode + VA-API (auto)
   ├─ 04-assets     icons + themes → /usr/share
   ├─ 05-hardening  nftables, DNS, AppArmor, journald caps,
   │                ramdisk tmpfs, CPU governor, sysctls
   ├─ 05-tweaks     tty banner, Ctrl+Alt+Backspace, tty1 → startx
   └─ 06-verify     checks it all took → writes install marker
        │
        ▼
  reboot → ./user-setup.sh     (per-user half)            per human
   ├─ 10-config     dotfiles, ~/bin, films.txt, $USER/$HOSTNAME tokens
   ├─ 11-browsers   stage ~/browsah + install ~/bin/browsers-setup
   └─ 12-welcome    welcome.txt, doris-welcome, AppArmor review timer
        │
        ▼
  first login: welcome screen → browser setup menu →
        both browsers configured, hardened, add-ons installed
        │
        ▼
  DONE — a workstation you can trust
```

## What each system task does

| task | what | why it exists |
|------|------|---------------|
| `00-check` | root, amd64, **networking** (hard fail), Wayland warn, kit self-test | die early, don't half-restore |
| `01-connection` | detect trusted-LAN vs direct-ISP → DNS posture | one kit, two network realities |
| `02-repos` | Mozilla, Helium, Sublime Text, GitHub Desktop; key fingerprints verified | only trusted, verified sources |
| `03-packages` | `packages/core.list` + auto-detected microcode/VA-API | curated set, hardware-aware |
| `04-assets` | icons + themes → `/usr/share` | root apps match the desktop |
| `05-hardening` | nftables, DNS, AppArmor, journald caps, debsecan, ramdisk, governor, sysctls | security is part of the restore |
| `05-tweaks` | tty banner, kill-X, boot to multi-user + tty1 startx | pleasant, keyboard-driven login |
| `06-verify` | confirms the important bits took, writes marker | the kit proves itself, or fails loudly |

## What each per-user task does

| task | what | why it exists |
|------|------|---------------|
| `10-config` | `config/`→`~/.config`, `bin/`→`~/bin`, `home/`→`~/`, tokens baked in | the person's desktop appears |
| `11-browsers` | stage `~/browsah`, install the browser assistant | browsers are the daily driver — set up right |
| `12-welcome` | generate welcome from the kit, install runner, arm timer | the kit documents itself; you learn your keys |

## The supporting machinery

- **`lib.sh`** — shared helpers every task sources: `log/warn/error/die`,
  `is_intel/is_amd`, `apt_install`, `backup_file`, `backup_and_copy`,
  `write_root_file`, `own_as_user`, `zip_backups`, `state_set/state_get`,
  `detect_connection`, `apply_tokens`, `run_tasks`. Tasks are thin; the
  shared library carries the discipline.
- **State markers** — `state_set`/`state_get` (mode, installed) let the kit
  remember decisions (DNS mode) and verify completion (install marker), so
  re-runs are safe and self-aware.
- **`tools/selftest.sh`** — gates every restore. Checks package lists parse,
  kit files exist, and shell-syntax-checks *every* `~/bin` script (by
  shebang, skipping ELF/xcf). If the kit is broken, restore won't start.
- **`tools/mkwelcome.sh`** — generates the welcome text *from the kit itself*
  (keybinds out of `rc.xml`, aliases out of `~/.bash_aliases`, timers out of
  `hardening/`). Docs can't rot if the kit generates them.
- **`tools/capture.sh` + `tools/scrub.sh`** — the kit rebuilds itself from a
  live box: capture re-vendors configs/scripts/hardening, scrub strips
  usernames, keys, and runtime junk. Review the diff, commit.
- **Token discipline** — `$USER`/`$HOSTNAME` baked at restore time, `$HOME`
  resolved at runtime. No hardcoded names, ever (hostnames change between
  installs; names get baked and the kit breaks).

## Security posture (the short version)

nftables default-deny inbound *and* outbound (outbound TCP relaxed to all
ports — see the FTPS story in the decision journal). DNS: auto-detected
posture — trusted router, or encrypted stubby when the link isn't trusted.
AppArmor in complain mode with a review reminder timer. journald capped,
debsecan weekly CVE scan, browser caches on a ramdisk so history never
touches disk.

## What DORiS is *not* (honest limits)

- One desktop paradigm (Openbox/X11), not a distro-hopping smörgåsbord.
- amd64 Debian trixie only — that's the supported surface, on purpose.
- No Wayland configuration (it warns and stays X11).
- No cloud, no telemetry, no container orchestrator — it's a desktop kit.
- The kit is opinionated: it recreates *this* way of computing, the way it
  was curated. That's the whole point.

---

*Next: [03 — The Decision Journal](03-decision-journal.md) — the if/then/buts.*
