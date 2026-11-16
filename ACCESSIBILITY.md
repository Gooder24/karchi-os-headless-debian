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
- **Assistive technology:** none has been tested yet; see [Checks](#checks).

## Known limitations

- **The installer's dialogs.** The test VM answers the installer's questions from the kernel command line, so it never
  sees the dialogs. Their keyboard operation and their output for a screen reader have not been checked. Tracked in
  #3 (keyboard) and #4 (screen reader).
- **The console display.** After the start the display is switched off. On the machine itself, `SUPER + D` lights it.
  Whether a screen reader user can work at the console in that state has not been tested. Tracked in #5.
- **Tables.** Three tables in the README have an empty header cell. The automatic check does not look at tables, so
  this was found by hand. Tracked in #2.

## Dependencies

Dependencies that show text or ask questions, and what is known about them:

- **debian-installer:** the text dialogs of the installer; see Known limitations.
- **The Linux console:** KarchiOS sets the `Lat2` console codeset for it. Its readability has not been tested.
- **fastfetch:** prints a system summary at each login. The screen reader check below covers it.
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

### Keyboard-only check (not run yet, tracked in #3)

On a test machine or in a VM, with no mouse attached:

1. Start the installer from the stick and answer each question with the keys the dialog shows, including Tab and the
   arrow keys.
2. For each question, check that every option can be reached, that the option with focus is visible, that focus moves
   in the order the options appear, and that the question can be left.
3. After the first start, press `SUPER + D`, log in on the console and run `karchi-doctor`. Check that every line can
   be read and that nothing needs a mouse.

Status: not run. The test VM does not press keys in the installer's dialogs (see Known limitations), so this needs a
person, or `tools/vm.py manual` with its key and screenshot commands.

### Screen reader check (not run yet, tracked in #4)

A person with a screen reader repeats the steps above with the screen reader on. They record the screen reader and its
version, the terminal or SSH client, and the machine. They check that each installer question and its options are
read, that the answer field is announced, and that the output of `karchi-doctor` is read line by line, status word
first. The checks in this repository run headless and cannot replace this step.

### Manual checks

- `karchi-doctor` writes its status as words (`ok`, `WARN`, `FAIL`) and uses no color codes. Checked by reading
  `pkg/root/usr/bin/karchi-doctor` on 16 November 2026.
- Zoom, reflow and color contrast: not tested. The size and colors of text come from the user's terminal.

### Documentation

Reviewed by hand on 16 November 2026: `README.md`, `CONTRIBUTING.md` and this file. The documentation contains no
images or videos. Problem found: the empty table header cells listed under Known limitations.
