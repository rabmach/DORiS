# 01 — The Path to DORiS

> Two commands, a USB stick, and a fresh net-install. Here's the road.

## What you need before starting

- A computer (amd64, Intel or AMD, any vendor)
- A USB stick (8 GB or larger)
- A [Debian trixie net-install ISO](https://www.debian.org/CD/netinst/)
- A way to write the ISO to the USB stick
- A terminal (you'll be in one after the install 'cos we raw doggin' it)
- Mrs. Grady's typing class, 4th period, 2nd-floor, 1977, Ox-Patch
- I may or not be kidding about that last one

A Debian box and a USB stick. 

## The concepts you'll use

These are the building blocks. If you've used a terminal before, you'll
recognize most of them. If you haven't, each one is explained in plain
language with the "why" behind it.

### sudo

After installing Debian, you have two users:**root** (the admin)
and **yourself** (regular user). The system half of DORiS needs root
privileges — it installs packages, writes to `/etc`, sets up a firewall.
The per-user half does not — it configures your dotfiles, installs your
browser assistant, writes to your home directory.

`sudo` lets a regular user run a command as root, without switching users.
You'll type `sudo ./restore.sh` for the system half, and just
`./user-setup.sh` for the per-user half. The difference matters: the
system half touches the whole machine; the per-user half touches only your
home.

### chmod +x

Your downloaded scripts are not executable by default. The system won't
let you run a thing it doesn't trust. `chmod +x` marks a file as safe to
run. You'll do this once, before the first run:

```sh
chmod +x restore.sh user-setup.sh
```

### ./

`./` means "run this thing in the current directory." Without it, the
shell looks for a command on the system PATH — and DORiS is not on the
system PATH. It's in front of you, in the directory you just cloned.

`./restore.sh` runs the script in front of you. `restore.sh` without
`./` does nothing useful — the shell doesn't know where it is.

### git clone

`git clone` copies a repository from GitHub to your machine. You'll
clone the DORiS repo once, and then run the scripts from inside it.
After the clone, the repo lives at `~/DORiS` (or wherever you put it).

### The two halves

DORiS splits into two scripts because one machine can have many users.
The system half runs once per machine. The per-user half runs once per
user. If you add a second user later, you run `./user-setup.sh` as that
user — the system half does not need to run again.

```
sudo ./restore.sh     # system half — once per machine
./user-setup.sh       # per-user half — once per user
```

Reboot between them. The system half installs packages, sets up a
firewall, configures DNS, enables AppArmor. Some of those changes need a
fresh boot to settle. What you may or may not have heard about not needing
to reboot Linux as much is true, a reboot here is fastest/easiest way to set
the changes just made.

## The path

From bare net-install to running DORiS. Here's every step.

### 1. Get the ISO

[Debian trixie net-install ISO](https://www.debian.org/CD/netinst/),
amd64. Smallest installer Debian offers — downloads everything over the
network. You end up with a minimal system. That's the point.

### 2. Write it to a USB stick

`dd`, Etcher, mintstick, whatever you trust. Bootable stick, Debian
installer on it. Done.

### 3. Boot and install

Boot from the USB. Arrow keys, advanced options, expert install.

- Set a root password (you'll need it in a minute)
- Create your regular user (name, password)
- Software selection: **standard system utilities only**. No desktop
  environment. DORiS provides the desktop.
- Grub: install to the disk

Reboot. You land at a tty login prompt. No desktop, no wallpaper, no
icons. Correct.

### 4. Login as root

Type `root`, hit enter. Type the root password, hit enter. You're in.

Two packages and one group:

```sh
apt-get update && apt-get install -y sudo git
adduser <youruser> sudo
```

Replace `<youruser>` with the name you created during install. `adduser`
puts you in the sudo group — that's the mad power.

Type `exit`, hit enter. You're back at the login prompt.

### 5. Login as your user

Type your username, hit enter. Type your password, hit enter. You're in.

Clone the repo, make the scripts executable, run them:

```sh
git clone https://github.com/rabmach/DORiS ~/DORiS
cd ~/DORiS
chmod +x restore.sh user-setup.sh
sudo ./restore.sh
./user-setup.sh
```

`sudo ./restore.sh` is the system half — installs packages, sets up the
firewall, configures DNS, enables AppArmor, icons, themes. 10-20
minutes.

`./user-setup.sh` is the per-user half — dotfiles, ~/bin scripts,
wallpaper, browser assistant. 5 minutes.

### 6. Reboot

Both halves done, reboot. Login again. Welcome message: keybinds,
aliases, scheduled jobs, credential chores. Browser setup assistant
offers Firefox and Helium.

### 7. Browser setup

Assistant launches the browser, waits for first-run, applies privacy
configs, opens each extension's add-on page. You click "Add to Firefox,"
alt-tab back to the terminal — assistant watches the profile until the
install lands. Per-browser done markers, skip and come back later.

## What you get

- Firewall: nftables, default-deny in and out
- DNS: auto-detected (trusted router or encrypted DoT)
- AppArmor: complain mode, review reminder
- Browsers: Firefox + Helium, privacy configs, extensions watched to
  completion
- Welcome screen: generated from the kit, never rots
- 191 curated packages: email, media, dev, monitoring, fonts, themes
- Keybinds: Win+K (KeePassXC), Win+T (terminal), Win+N (music),
  Win+F (Thunar), and more
- Docs: decision journal, bug log, this path — all in the repo

## What you don't get

DORiS is a restore system, not a distro. One way of computing on Debian
trixie. No desktop choice menu, no Wayland, no cloud, no telemetry, no
hand-holding beyond the 191 packages it provides.

Stress. You will get no stress from DORiS.

If something breaks, the bug log tells you why. If you're curious about
a decision, the decision journal explains it.

---

*One stick. One button. Offline. ka-BAM.*

---

[Back to the README](../README.md)
