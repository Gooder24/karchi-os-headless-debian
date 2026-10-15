# KarchiOS Headless (Debian)

A server OS for old laptops that run AI coding agents day and night. One ISO installs Debian 13 **without a
network**; after that the machine starts by itself, joins the network and your tailnet by itself, updates
itself, reboots only while no agent works, and tells you what is wrong. Nobody has to sit at it again.

It is Debian 13 plus three layers, each of which does one job and can be used on its own:

```
karchi-headless              this repository: the installer ISO, the network, Tailscale, the health check
 ├─ laptop-server            github.com/Gooder24/laptop-server       the laptop behaves like a server
 ├─ reboot-when-idle         github.com/Gooder24/reboot-when-idle    updates and reboots that wait for agents
 └─ Debian 13 (trixie)       base system, unattended-upgrades, iwd, systemd-networkd, Tailscale
```

## What makes a good server OS for an agent box

An "agent box" is a machine where Claude Code, Codex and friends work for hours unattended: long turns,
background builds, dev servers, scheduled prompts. It sits in a corner, reached only over the network. What it
needs, and which part gives it:

| the server must | so that | given by |
|---|---|---|
| install from one stick, with no network and three questions | setting up the next laptop takes 5 minutes, also where Wi-Fi needs a password typed in | the installer ISO (this repo) |
| start by itself and come back by itself | a power cut, a kernel update or a hang ends with the machine back online, not waiting at a menu, a lid or a dead clock battery | laptop-server, reboot-when-idle, this repo |
| be reachable from anywhere, without opening ports | agents and you reach it over SSH from any network | Tailscale with Tailscale SSH (this repo) |
| never stop because it is a laptop | a closed lid, an idle timer or a stray suspend does not take it offline | laptop-server |
| not wear itself out | the screen is dark, the battery stays at 80 %, the SSD is not swapped on | laptop-server |
| stay patched without killing work | security fixes come every day; the reboot a new kernel needs waits until no agent turn, background task or build runs | unattended-upgrades + reboot-when-idle |
| survive a bad kernel | a new kernel boots once on trial; without network, after a crash or a hang it goes back to the old one | reboot-when-idle |
| be light | more of an old laptop's memory is left for agents and builds | Debian's base, no desktop: 696 MB on disk, 263 MB of memory after the start, started in 3.8 s |
| say what is wrong | one command over SSH instead of a monitor and a keyboard | `karchi-doctor` |

## The parts

### 1. Debian 13 and the installer ISO (this repository)

Why Debian: stable releases with security updates for years, a signed boot loader (it installs with Secure
Boot on), `debian-installer` that knows partitioning, firmware and boot loaders on any x86 laptop, and `apt`
updates that work from the first day.

The ISO is Debian's official netinst with three changes (see [How the ISO is made](#how-the-iso-is-made)): the
installer's answers, a boot menu with one entry, and a folder with our packages and every package the netinst
lacks. It installs offline, asks three things up front and then needs nobody:

- the machine's name, the user and their password (root stays locked; the user has `sudo`);
- the time zone, the Wi-Fi network and its password, and a Tailscale auth key, each of which may stay empty;
- where to install: a whole disk, or only the free space next to another system (Windows stays).

The keyboard is Slovak QWERTY, in the installer and in the installed system (`iso/preseed.cfg`; change it there
for your own build). The root file system is btrfs with one subvolume `@rootfs`, without disk encryption, so the
machine starts without anyone typing a passphrase. Firmware for Intel graphics and Wi-Fi and the CPU microcode
are installed only where that hardware is.

### 2. laptop-server: the laptop behaves like a server

[github.com/Gooder24/laptop-server](https://github.com/Gooder24/laptop-server), a package of its own.

| | why |
|---|---|
| the lid does nothing | close it, stack it, put it on a shelf: it keeps serving |
| the machine never sleeps | not the lid, not an idle timer, not a stray `systemctl suspend` |
| the display is dark after the start, `SUPER + D` switches it | the panel is the biggest power draw and wears out; at the machine, one key gives the console |
| charging stops at 80 % | a lithium battery kept full for years loses its capacity; at 80 % it lasts and still covers a power cut |
| swap in compressed memory (zram) | old laptops have little memory; no swap partition wears the SSD |
| the boot menu does not wait | after a power cut the machine is back in seconds |

`laptop-server check` tells whether all of that holds.

### 3. The network that needs nobody (this repository)

| | why |
|---|---|
| Wi-Fi through `iwd`, which gives itself an address; the network from the installer is in `/var/lib/iwd` | `iwd` reconnects by itself after an outage, with no NetworkManager or desktop agent |
| a cable through `systemd-networkd`, any `en*` interface, DHCP | plug in a cable or a USB adapter and it works, no setting |
| names through `systemd-resolved` | one resolver for Wi-Fi, cable and Tailscale's MagicDNS |
| the start does not wait for a cable (`systemd-networkd-wait-online` is off) | a machine on Wi-Fi does not wait two minutes at every start |
| Tailscale; with an auth key from the installer the machine joins your tailnet at its first start, with Tailscale SSH on | reach it from anywhere, with no open port and no SSH keys to manage; the key is deleted once used |
| no `sshd` | the way in is Tailscale SSH: nothing listens on the local network |

### 4. Updates and reboots that wait for agents

[github.com/Gooder24/reboot-when-idle](https://github.com/Gooder24/reboot-when-idle), a package of its own,
and `unattended-upgrades` set up by this repository (`/etc/apt/apt.conf.d/52karchi-unattended-upgrades`).

- Debian's security and stable updates install themselves every day. `unattended-upgrades` would also reboot
  at a fixed hour, whatever runs; that is off.
- Every night between 03:00 and 04:00 `reboot-when-idle` looks whether a reboot is due (a newer kernel, a
  package asked for it, 30 days up) and whether anything works: an agent turn (Claude Code hooks), a
  conversation that paused a moment ago, an agent's background task, whatever runs in a login session, a job
  under `reboot-when-idle hold`, apt, someone typing. It reboots only when nothing does, and tries again for
  three hours, then the next night.
- A new kernel boots once, on trial (`GRUB_DEFAULT=saved`, `panic=10`, the hardware watchdog): if the network
  does not come up with it, or it crashes or hangs, the machine goes back to the kernel that worked.

For Claude Code to say when it works, merge `/usr/share/reboot-when-idle/claude-code-hooks.json` into
`~/.claude/settings.json` of the user the agents run as; `karchi-doctor` reminds you when it is missing.

### 5. The health check (this repository)

`karchi-doctor`, on the console or over SSH, as yourself: failed services, the network and Tailscale, then
`laptop-server check` and what `reboot-when-idle status` says needs a look. `ok`, `WARN` with what to do by hand,
`FAIL` with exit code 1.

### 6. KarchiOS touches (this repository)

`fastfetch` at every interactive login, on the console and over SSH; the Slovak QWERTY keyboard with the
`Lat2` console font; the machine name `karchi-server` offered by the installer. Change these for your own build.

## Install on a real machine

Copy the ISO onto a Ventoy stick next to the others (`make usb DIR=/run/media/$USER/Ventoy/ISO`, nothing is
erased), or write it to a stick of its own. The machine has to start through **UEFI**; Secure Boot may stay on
(Debian's boot loader is signed).

The installer asks in this order, then needs nobody:

1. the name of the machine (default `karchi-server`);
2. the user's name and password (root stays locked, the user has `sudo`);
3. the time zone (default `Europe/Bratislava`);
4. the Wi-Fi network and its password (empty = no Wi-Fi);
5. the Tailscale auth key (empty = log in later by hand);
6. where to install, when there is a choice: every disk as a whole (`ERASE the whole disk`) and, when a disk
   with partitions has at least 10 GB unallocated, also `only its N GB of free space`. The second choice comes
   first in the list, takes only the largest contiguous unallocated stretch and leaves existing partitions
   alone (Windows, for example). The stick the installer runs from is not in the list;
7. the confirmation to write to the disk. For a whole disk **the whole chosen disk is overwritten** and the list
   shows partitions #1 and #2; for free space it shows only new partitions with higher numbers. The default
   answer is "No".

Next to another system: the space has to be unallocated (not an empty volume). The boot loader goes into the
existing EFI partition, into the folder `debian`; the other system's files stay. The machine then starts into
KarchiOS without a menu; the other system is started from the firmware's boot menu.

The keyboard is not asked: it is Slovak QWERTY already during the installation (so the password is typed the
same way as later on the console; digits are with Shift) and in the installed system. The installer's own list
offers only Slovak QWERTZ, so the answer is given in advance. Another keyboard: `sudo dpkg-reconfigure
keyboard-configuration`.

Tested with Ventoy 1.1.17 (UEFI, GPT, "Boot in normal mode").

When the installer stops with an error, `Alt + F4` shows its log (back with `Alt + F1`); the lines with `E:` say
why.

After the restart the display goes dark. `SUPER + D` lights it; the console shows a login prompt.

```
karchi-doctor                               what works and what is still to be done by hand
sudo tailscale up --ssh                     if the installer got no auth key
iwctl station wlan0 connect <network>       Wi-Fi afterwards
reboot-when-idle status                     is a reboot due, and what would hold it back now
```

Updates install themselves; `sudo apt update && sudo apt full-upgrade` does it at once.

## Build and test

```
git clone --recurse-submodules https://github.com/Gooder24/karchi-os-headless-debian
make check      # static checks and self-tests, also of the parts; seconds
make iso        # the ISO into ~/.cache/karchi-os-headless-debian/out; the first run downloads about 0.9 GB
make vm-test    # install without network into a fresh VM, two starts with a power cut between, checks
```

None of it needs root. The build runs in the official `debian:trixie-slim` under bubblewrap, which
`tools/sandbox.sh` downloads by itself on its first run, so it works on hosts without `apt`, `dpkg-deb` or
`xorriso` (Arch, for example) as well as on Debian. `make vm-test` needs QEMU with KVM and OVMF
(Arch: `qemu-full edk2-ovmf`, Debian: `qemu-system-x86 ovmf`).

### How the ISO is made

Debian's official netinst stays as it is except for three things:

1. `preseed.cfg` is added to the installer's initrd (the installer reads it before its first question), with two
   of its files extended with Slovak QWERTY: the table of keymaps, and the list of keyboards its question
   knows. An answer that is not in that list the installer silently replaces with the default `us`, and the
   installed system then inherits it. The build therefore runs the keyboard step in the installer's own
   userland and fails unless the keyboard of `preseed.cfg` comes out of it unchanged.
2. The boot menu has one entry and starts it by itself after 5 seconds.
3. A folder `/karchi` is added: our scripts, and `pool/` with our packages (`karchi-headless`, and
   `laptop-server` and `reboot-when-idle` built from `parts/`) and the packages the netinst lacks (`iwd`,
   `systemd-resolved`, `keyd`, `fastfetch`, `systemd-zram-generator`, `tailscale`, `unattended-upgrades` and
   their dependencies).

The list of missing packages is not kept by hand: `apt` works out what installing `karchi-headless` would take on
an entirely empty system, and everything the netinst already carries in the same version is left out. Tailscale
comes from `pkgs.tailscale.com` (`apt` checks its signature), the rest from `deb.debian.org`.

The boot records (BIOS, UEFI, the partition table for a USB stick) are rewritten by `xorriso` in the same form
the netinst has them.

`make iso` ends with `tests/check-medium.sh`: it takes the `apt` commands that `iso/late` runs out of the
finished ISO and runs them in the sandbox with the clock set to 2013. They have to succeed from the medium
alone. An old laptop with a dead clock battery starts in the past, and `apt` then refuses a `Release` file newer
than its clock ("not valid yet"); the installer shows only `"sh /cdrom/karchi/late" failed with exit code 100`.
That is why `late` does not check dates (`Acquire::Check-Date=false`).

### The test in a VM

`make vm-test` starts the installer's kernel directly and gives it, on the kernel command line, the answers a
person would type (`ANSWERS` in `tools/vm.py`). The installation runs without a network card, and the ISO is
attached as a USB stick: the stick is a disk too, and the installer must not offer it to be overwritten (if it
did not recognise it, it would stop at the disk question and the gate would fail). Then it starts the installed
disk, runs `tests/check-installed.sh` over SSH, and measures on the VM's screen that it is dark after the start,
that an ordinary key does not light it, and that `SUPER + D` lights it and darkens it. Finally it pulls the power
and does it all again.

`tests/check-installed.sh` checks, among others: no failed service; btrfs root and the EFI partition; swap only
in zram; the answers of the installer (name, time zone, Wi-Fi network known to `iwd`, root locked); the network
services; the lid and sleep; Tailscale waiting for a login without a key; the dark display; the Slovak console
keyboard; the boot menu not waiting; GRUB keeping the running kernel with `panic=10` for trial boots; automatic
updates without their own reboot; the network package sources; `karchi-doctor` finding nothing broken; and a
budget of lightness (packages, disk, memory).

Only the test installation has SSH and passwordless `sudo`: `karchi/test-key=…` on the kernel command line
turns them on.

In the VM the stick is writable like a real one (Ventoy does not start from a read-only stick), but the writes
go into a layer QEMU throws away when it ends (`snapshot=on`): the ISO file does not change.

Measured on 15 October 2026: installation in 101 s, 266 packages, 696 MB on disk, 263 MB of memory after the
start, started in 3.8 s. The limits in `tests/check-installed.sh` are the first green run (11 October 2026)
plus 15 %.

The gate does not see the installer's dialogs. Those are checked by hand:

```
python3 -B tools/vm.py manual      # start from a stick with the ISO through its menu, two disks, no answers
python3 -B tools/vm.py manual ~/.cache/karchi-os-headless-debian/vm/ventoy.img   # the same from a Ventoy stick's image
python3 -B tools/vm.py shot        # a screenshot (PNG) once the screen stops changing
python3 -B tools/vm.py key ret     # keys: ret, tab, down, alt-f2 (installer console), alt-f4 (its log)
python3 -B tools/vm.py type text
```

The image of a Ventoy stick cannot be made on the host without root. It was made in the test VM (`vm.py up` with
an empty image as a second disk, `Ventoy2Disk.sh -I -g /dev/vdb` inside, and the ISO copied into `ISO/`).

### What the VM does not check

A real Wi-Fi connection, turning off a laptop panel's backlight, the lid switch, the battery's charge limit, and
logging in with an auth key. On a real machine `karchi-doctor` shows them.

The display: `laptop-server display off` blanks the console by force (`setterm --blank force`), so a key press
does not light it, and switches the backlight off (`bl_power`). Writing to `/sys/class/graphics/fb0/blank` is not
enough: the first key press undoes it. When a graphics driver takes the screen over only after the service has
run, a udev rule restores the state.

`getty@tty1` has `TTYVTDisallocate` off: otherwise systemd clears the screen together with its history when the
getty starts, the kernel sets the video mode again and the output comes back on, although the console stays
"blanked". At the start of the system that was a race with `laptop-server-display-off.service`; after a logout
on the console the display would light up every time. The test therefore also reads the state of the output
straight from the driver (`/sys/kernel/debug/dri/0/state`).

A known limit: after being switched off, the machine does not switch itself on; that is up to the firmware.
Everything after the power button press runs unattended.

## Repository layout

| path | what |
|---|---|
| `pkg/control`, `pkg/root/`, `pkg/preinst`, `pkg/postinst`, `pkg/postrm` | the `karchi-headless` package; `root/` is installed as it is |
| `parts/laptop-server`, `parts/reboot-when-idle` | the two parts, git submodules of their own repositories |
| `iso/preseed.cfg` | answers for the Debian installer (everything except what a person is asked) |
| `iso/sk-qwerty.ekmap` | Slovak QWERTY for the installer: its own table of keymaps lacks this variant |
| `iso/questions`, `iso/templates` | our questions: time zone, Wi-Fi network and password, Tailscale auth key, disk |
| `iso/late` | the installer's last step: our packages from the medium, then `post-install` with the answers |
| `iso/grub-entry.cfg` | the boot menu's only entry |
| `tools/sandbox.sh` | a Debian userland without root (bubblewrap); the build runs in it |
| `tools/build-iso.sh` | builds the ISO |
| `tools/vm.py` | the test VM: installation, start, checks, keys, screenshots |
| `tests/check-installed.sh` | checks of the installed system |
| `tests/check-medium.sh` | a check of the finished ISO: everything `iso/late` asks for is on the medium, also with a wrong clock |
| `build.conf` | version and checksum of the netinst ISO, size of the test VM |

Large files live outside the repository in `~/.cache/karchi-os-headless-debian` (`KARCHI_CACHE` points
elsewhere, e.g. for a second build next to the first): `dl/` (the netinst, the sandbox's root file system),
`sandbox/`, `build/`, `out/` (the finished ISO, the installer's kernel and initrd for the test), `vm/` (the test
VM's disk, logs).

## Not in this version, on purpose

Disk encryption unlocked by the TPM; `sshd` with keys for agents (the way in is Tailscale SSH); AI tools
themselves; reinstalling while keeping the home directory; starting through BIOS; updates of Tailscale itself
through `unattended-upgrades` (`apt full-upgrade` updates it).

## License

MIT
