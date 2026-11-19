# Accessibility

KarchiOS Headless is installed and run from a keyboard, on the console or over SSH, and nearly all of it is text:
the installer's questions, the messages of its log, and the output of `karchi-doctor`. Anyone who installs, runs or
contributes to it should be able to do so with the keyboard alone, with a screen reader or a braille display, and
without having to say whether they have a disability.

## Priorities

- **Keyboard only.** The installer and the tools are text-only and need no mouse. Every choice must be reachable
  with the keyboard, and the option that has focus must be visible.
- **Text that a screen reader can read.** Status is written as words (`ok`, `WARN`, `FAIL`), never as a color or a
  symbol alone. New output stays plain text.
- **Readable documentation.** Headings follow each other without skipped levels, links say where they go, images
  have alternative text, and tables have header cells.
- **Standards.** WCAG 2.2 Level AA does not apply directly to a terminal or an installer. Its success criteria guide
  the documentation and any graphical interface added later.

## Contributor expectations

- **Documentation.** Run `python3 .github/scripts/check-docs.py`. It fails on skipped heading levels, empty headings,
  images without alternative text and link text such as "here". Check by hand that every table has header cells and
  that code blocks hold only commands and their output.
- **Output and questions.** New or changed output (`karchi-doctor`, the installer's questions) states its status in
  words, does not depend on color, and can be answered with the keyboard.
- **Installer questions.** A change to them is also checked by hand: the keyboard-only steps under
  [Checks](#checks), and the screenshots from `python3 -B tools/vm.py manual`, described in the README under
  "The test in a VM".
- **Pull requests.** The accessibility section of the pull request template is filled in. A change that adds or moves
  a barrier says so in the pull request and has an issue labeled `accessibility`.
- **Automatic check.** `.github/workflows/accessibility.yml` runs the documentation check on each pull request and on
  `main`. Problems that already exist are listed in `.github/a11y-baseline.json`, and each has an issue. A new problem
  fails the check.

## Reporting accessibility barriers

Open an issue with the [accessibility form](https://github.com/Gooder24/karchi-os-headless-debian/issues/new?template=accessibility.yml).
The issue is labeled `accessibility`. If the form does not work with your tools, open a plain issue with the same
details. If you cannot use GitHub, ask someone who can to open the issue for you.

Say what you were trying to do, what happened, where you were (for example the installer question, or the output of
`karchi-doctor`), the steps in order, your machine and your terminal or SSH client, your assistive technology with its
version, and a severity from the list below. Screenshots and recordings are optional. Do not paste passwords, Wi-Fi
keys or Tailscale auth keys.

### Severity

- **Critical:** stops a core task, for example the installation cannot be finished, or `karchi-doctor` cannot be read.
- **Serious:** a major difficulty, but a workaround exists.
- **Moderate:** an annoyance, or an experience that is inconsistent.
- **Minor:** little effect on use.

## How we respond

- We treat every report as expertise, not as a complaint.
- We acknowledge each report, give it a severity and an owner, and label it `accessibility`. Where we know a
  workaround, we name it.
- When a report is unclear, we ask what was seen or typed instead of dismissing it, and we try to reproduce it before
  we close it.
- We say when the status or the next step changes, and we ask the reporter to confirm a fix where they can.
- No fixed response time is promised yet.

## Ownership

The owner of accessibility for this repository is the repository owner, Gooder24. The owner:

- triages accessibility issues and sets their severity and labels;
- keeps the known barriers visible in the open issues labeled `accessibility`;
- reviews the accessibility section of each pull request;
- keeps this file current, and repeats the checks below when the installer or the tools change.

## Supported environments

- **Hardware:** x86-64 (amd64) PCs and laptops that start through UEFI.
- **Tested:** the installation in a QEMU virtual machine without a network card (`make vm-test`), and a stick made with
  Ventoy 1.1.17 booted through UEFI with GPT, as the README records. Other hardware is not recorded here.
- **Language:** the installer runs in English (en_US.UTF-8). The keyboard is Slovak QWERTY, in the installer and in the
  installed system.
- **Ways in:** the physical console, and SSH through Tailscale.
- **Assistive technology:** Orca 48.1 on `karchi-doctor`, `fastfetch` and the README (19 November 2026); not in the
  installer, which has no speech yet (#10). See [Checks](#checks).

## Known limitations

- **The installer's dialogs.** The test VM answers the installer's questions from the kernel command line, so it never
  sees the dialogs. Go Back in our own questions now returns to the previous one and, from the first, to the
  main menu (#8, #9, re-checked by hand on 19 November 2026); #3 remains incomplete.
  No screen reader can read them yet: the boot menu has no speech synthesis entry (#10).
- **The console display.** After the start the display is switched off. On the machine itself, `SUPER + D` or `Ctrl + Alt + D` lights it.
  Whether a screen reader user can work at the console in that state has not been tested. Tracked in #5.
- **Local screen reader.** No `brltty` or `espeakup` setup is supplied by `pkg/` (#7). SSH from a machine
  with the user's own screen reader is a possible route after networking and access setup; it does not cover installation.

## Dependencies

Dependencies that show text or ask questions, and what is known about them:

- **debian-installer:** the text dialogs of the installer; see Known limitations.
- **The Linux console:** KarchiOS sets the `Lat2` console codeset for it. Its readability has not been tested.
- **fastfetch:** prints a system summary at each login. A screen reader reads its logo in front of every line (#11).
- **laptop-server:** switches the display off; see Known limitations.
- **Tailscale:** gives the SSH access. Its own interface is not used here.
- **Chromium:** installed for agents, which run it headless. No interface of this project is built on it.

No upstream accessibility issue has been reviewed or linked yet. Before a new dependency that shows text or asks
questions is added, read its accessibility notes and run the keyboard-only and screen reader steps on it.

## Taking part

- Participation is asynchronous for now: issues and pull requests. No meeting or chat channel is offered yet.
- To ask for something you need in order to take part, open an issue that says what you need. You do not have to
  explain why.
- Open accessibility issues labeled `good first issue` or `help wanted` are the places to start. Each one states its
  scope and what done looks like.
- Accessibility work is credited in the release notes, with the contributor's consent and in the way they ask for.
  Testing, reports and documentation count as much as code.
- Progress is reported in the release notes: completed accessibility work, open issues labeled `accessibility`, and
  known limitations.
- The documentation check, [`.github/scripts/check-docs.py`](.github/scripts/check-docs.py), can be copied to other
  projects. It needs only Python 3 and git. The repository owner maintains it.

## Checks

This section records what has been run. A check counts as done only when its result is written here.

### Automatic check

`python3 .github/scripts/check-docs.py` covers the Markdown files: skipped heading levels, empty headings, images
without alternative text, and vague link text. It is configured in `.github/workflows/accessibility.yml`. Local run on
16 November 2026: no problems.

### Keyboard-only check (partial, 18 November 2026, tracked in #3)

Repeat on a test machine or VM without a mouse:

1. Start from the stick and answer each question with its documented keys, including Tab and arrows.
2. Reach every option, check visible focus and its order, and leave every question with Go Back (or No where offered).
3. After first boot, test both display shortcuts, log in on the console and run `karchi-doctor`; read every line.

Run on ASUS host Debian 13, QEMU q35/KVM with OVMF UEFI, 2 CPUs, 2 GiB RAM, a 16 GiB `vda`
and 2 GiB `vdb`, no network during installation. ISO: `karchios-headless-debian-2026.11.18-x86_64.iso`,
SHA256 `78477eec25c45709d55c0788b8ed61dda9a112944249a67bb35027305c013194`. Source: headless
`e289a02`, laptop-server `252c898`. The ISO was built from the changed working tree before the commits.
All manual interaction used `tools/vm.py key`, `type` and `shot`, without SSH or a mouse. Hostname,
username, password and Tailscale key were fictional. The target was `vda` (shown as 17 decimal GB), never `vdb`.

Screenshots before and after every Tab/arrow, pixel differences and the observation log are retained outside git
in this task's scratch directory, `overenie/3/` and `overenie/observations.md`. Each image was visually inspected.
The evidence sequence numbers below identify the originals; AE is the number of changed pixels, not a claim
that a particular widget changed. A focus claim also required looking at the before/after images.

Observed order and results:

| Question or step | Observed keyboard result | Evidence |
|---|---|---|
| GRUB install entry | Selected entry visible; automatic boot occurred before navigation was captured. Navigation unverified. | 001; 002/003 already show installer, AE 0 |
| Hostname | Tab field to Continue visible; fictional value entered after returning from main menu. Left from Continue returned to field. Go Back unverified. | 005/006 AE 1408; 032/033 AE 1408; 035/036 AE 1408 |
| Username | Tab field → Continue → Go Back; Enter on Go Back leaves to main menu. Up selects network, Enter reopens hostname. | 011/012 AE 1408; 014/015 AE 2432; 017/018; 020/021 AE 12544 |
| Password | Tab field → Show Password checkbox → Continue → Go Back; Go Back returns to username. | 048/049 AE 256; 051/052 AE 1408; 054/055 AE 2432; 057/058 |
| Password confirmation | Same Tab order; Go Back returns to password. Password then reentered twice. | 061/062 AE 256; 064/065 AE 1408; 067/068 AE 2432; 070/071 |
| Time zone | Tab field → Continue → Go Back visible, but Go Back moves forward to Tailscale and skips queued Wi-Fi questions: barrier #8. | 074/075 AE 1408; 077/078 AE 2432; 080/081 |
| Wi-Fi SSID/password | Not shown after the preceding Go Back; unverified, skipped by #8 rather than preseed. | 081 |
| Tailscale key | Tab field → Continue → Go Back visible; Go Back advances to disk selection: same barrier #8. | 083/084 AE 1408; 086/087 AE 2432; 089/090 |
| Where to install | Down selects vdb, Up returns to vda; Tab reaches Go Back, Enter redisplays this question: barrier #9. Then vda accepted. | 092/093 and 095/096 AE 9984 each; 098/099 AE 5544; 101/102 |
| Write changes to disks | Only vda listed. Tab No → Yes visible; Left while Yes focused does nothing (AE 0). Enter accepted Yes. The No/exit path was not tested. | 108/109 AE 1152; 111/112 AE 0; 114/115 |

Questions answered by `iso/preseed.cfg` did not appear and are **unverified**: locale/language, keyboard layout,
network interfaces and domain, firmware loading, root/full name and home encryption, UTC/NTP and the standard
Debian time-zone question, partition recipe/label/swap and existing LVM/RAID removal, kernel selection, mirror
and package/task selection, popularity contest, GRUB target/fallback and final reboot notice. This run does not
claim keyboard coverage of those hidden paths or other disk layouts.

Step 1 is incomplete: installation questions were exercised, but GRUB navigation was not captured.
Step 2 failed: #8 and #9 prevent the required return paths; hostname Go Back and write-confirmation No are
also unverified. #3 remains open. The installer was not changed in this audit.

Re-check of Go Back after the fix of #8 and #9, 19 November 2026, same VM setup, ISO
`karchios-headless-debian-2026.11.19-x86_64.iso` (SHA256 `b57eacb9c339c513fd985512fa1194a7c19279e0d7dc0cfbe3170a3c8ac85a09`),
keyboard through `tools/vm.py` only. Time zone, Continue, then
Wi-Fi network name (now shown) and Wi-Fi password. Go Back from the Wi-Fi password returned to the network name
with its answer kept; Go Back from the Tailscale key returned to the Wi-Fi password; Go Back from "Where to
install" returned to the Tailscale key. Go Back from each question in turn led back to the time zone and from it
to the installer's main menu, with "Partition disks" selected and no error. Enter there asked our questions
again with the earlier answers as defaults (a password field is always empty, as Debian's own are), and after
them "Write the changes to disks?" listed only `vda`, the disk chosen. The No path of that confirmation and the
GRUB menu remain unverified.

Step 3 passed for keyboard operation in this VM: the first-boot display was dark; `SUPER + D` showed
the login prompt and hid it again (124/125, 126/127); `Ctrl + Alt + D` did the same (129/130, 132/133).
The first pair changed resolution; its pixel diff uses black padding to the larger size (AE 1856); the other
three have AE 812, 796 and 812. This proves the VM image switches, not physical panel backlight behavior.
Console login succeeded (135/136). Typing `karchi` and Tab completed `karchi-doctor` (138/139, AE 130).
Its entire output and the returned shell prompt are visible in 141: status words are readable, all checks report
`ok` except `WARN` that Tailscale is not logged in, expected with fictional credentials. No mouse or guest SSH
was used. The installation finished and powered off automatically; `up` then hit its expected 240-second test-key
SSH timeout, after which only console keys were used. The VM was stopped and its PID confirmed absent afterward.

### Screen reader check (19 November 2026)

Orca 48.1 with speech-dispatcher 0.12.0 on thinkpad-e540 (KarchiOS Headless, karchi-headless 2026.11.11), commands
typed into lxterminal as they would be over SSH; the README as GitHub renders it, in Chromium 156. An agent ran it
with `citacka` (karchi-skills), which writes down the text Orca sends to the synthesizer: the words, not the voice.
The transcripts are in [this gist](https://gist.github.com/Gooder24/f2446d346e695aaa6b8d2a8436a0fbd3).

- **The installer's questions:** not read. The installer has no screen reader: the ISO's boot menu lost Debian's
  speech synthesis entry (#10), and the installed system has no console screen reader either (#7). None of the
  seven questions (the machine's name; the user and password; the time zone; the Wi-Fi network and password; the
  Tailscale auth key; where to install; the confirmation) nor their options and answer fields can be heard until
  #10 is fixed; then this check is repeated in the VM with speech.
- **`karchi-doctor`:** every line is read as it appears, status word first (`ok    no failed service`), and again
  line by line in flat review. All lines were `ok` on this machine, so no `WARN` or `FAIL` line was heard.
- **`fastfetch`:** the logo is read in front of each line of the summary (#11).
- **README:** the layer diagram, drawn with box characters, and two blocks of commands with aligned descriptions
  read badly; they are lists now (`3fd9d4d`).
- **Not checked:** braille, NVDA or VoiceOver over SSH, and a voice's pronunciation of the symbols in code.

### Manual checks

- `karchi-doctor` writes its status as words (`ok`, `WARN`, `FAIL`) and uses no color codes. Checked by reading
  `pkg/root/usr/bin/karchi-doctor` on 16 November 2026.
- Zoom, reflow and color contrast: not tested. The size and colors of text come from the user's terminal.

### Documentation

Reviewed by hand on 16 November 2026: `README.md`, `CONTRIBUTING.md` and this file. The documentation contains no
images or videos. Problem found in that review: empty header cells in three `README.md` tables; `10f0ad1` fixed them.
