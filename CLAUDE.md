# KarchiOS Headless (Debian)

What is where, how it is built and tested: `README.md`. The parts `laptop-server` and `reboot-when-idle` are
git submodules under `parts/`, each its own repository on GitHub (Gooder24/laptop-server,
Gooder24/reboot-when-idle) with its own README, tests and CLAUDE.md rules: a change to a part is committed and
pushed there first, then the submodule is moved here (`git -C parts/<part> pull`, commit the new pointer).

## Rules for working in this repo
- Code comments, messages and documentation are in English.
- Nothing needs root on the host: the build runs in the sandbox (`tools/sandbox.sh`), the tests in QEMU.
- Large files (the downloaded netinst, the sandbox, ISOs, VM disks) live in `~/.cache/karchi-os-headless-debian`,
  not in the repo (`KARCHI_CACHE` points elsewhere, e.g. for a second build next to the first).
- The x270 host has 15 GB of memory and is often full: look at `free -h` before `make vm-test`, and do not run it
  next to the VMs of `karchi-os`.
- What belongs to any laptop server goes to laptop-server, what belongs to any agent machine to reboot-when-idle;
  this repo keeps the installer and what is KarchiOS's own (network, Tailscale, karchi-doctor, the keyboard).

## Testing
- `make check` — static checks and self-tests on the host, also `make check` of both parts (seconds).
- `make iso` ends with `tests/check-medium.sh` (in the sandbox, no VM): the `apt` of `iso/late` has to succeed from
  the medium alone, with the clock in 2013.
- On the way, `make iso` runs the installer's keyboard step in the installer's own userland (`chroot` in the
  sandbox, no VM): the keyboard of `iso/preseed.cfg` has to come out of it unchanged, or the build fails.
- `make iso && make vm-test` — the gate: installation without network into a clean VM, two starts with a power
  cut between them, `tests/check-installed.sh` and `SUPER + D` through the VM's keyboard. About 10 minutes.
  A change to the installer's questions is not done until the gate has run: the installer stops at a question
  the gate does not answer, and the gate then fails after 15 minutes with a screenshot.
- A change to the installer's questions or the boot menu is also checked by hand with `tools/vm.py manual`
  (screenshots): the gate answers from the kernel command line and does not see the dialogs.
- Nontrivial logic has one runnable check (`--self-test`), not a suite of tests per function.
