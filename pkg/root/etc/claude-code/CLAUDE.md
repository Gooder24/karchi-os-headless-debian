# This machine: a KarchiOS Headless agent box

Debian 13 on a laptop without a desktop, display or sound, reached over Tailscale SSH. Agents work here for hours
unattended, several at a time, next to long-running services. `karchi-doctor` says what is wrong with it.

## Tools
- Every shell has them, a command over SSH (`ssh <box> '<command>'`) too: git, rg, jq, xxd, file, sqlite3, dig,
  unzip, zip, rsync, bc, column, tmux, make, gcc, python3 with venv, chromium, and what users install into
  `~/.local/bin`, `~/.bun/bin`, `~/.cargo/bin`, `~/go/bin` or mise (`/usr/lib/karchi/agent-path`).
- Disk health: `sudo smartctl -H -A /dev/<disk>` (smartmontools; `smartd` watches the disks and logs to the journal).
- A tool that is missing and other agents will need too belongs in the `Depends` of karchi-headless
  (github.com/Gooder24/karchi-os-headless-debian, `pkg/control`), not only in this machine's `apt install`.
- Web pages and UIs: `chromium --headless=new --window-size=1366,768 --screenshot=<file.png> <url>`, or Playwright
  with `executablePath: '/usr/bin/chromium'`; no browser download is needed. Close every browser you start.

## Sharing the machine
- Before a heavy job (a VM, an ISO or a large build, several browsers) look at `free -h` and `uptime`. With less
  than 2 GB available, or a load above `nproc`, wait or make the job smaller.
- When memory runs out, earlyoom ends the largest browser, VM or compiler first and never the agents, T3, SSH or
  Tailscale. "Killed" with no other error means memory ran out, not a bug in the code.
- A long job outside an agent turn: `reboot-when-idle hold <command>` keeps the nightly update reboot away while it
  runs. Agent turns and their background commands already count.
- A server you start listens on 127.0.0.1 or the Tailscale address, on a free port (`ss -ltn`). Stop it when you
  are done, unless it is meant to stay: then it is a `systemctl --user` unit (lingering is on).
