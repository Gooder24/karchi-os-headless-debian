# Contributing

Thank you for helping. The repository owner, Gooder24, reviews every change. Changes come as issues and pull requests.
For a larger change, open an issue first, so the approach can be agreed before you write it.

Accessibility applies to every change. Read [ACCESSIBILITY.md](ACCESSIBILITY.md) first: it lists the expectations,
how to report a barrier, and which checks have been run.

## Checks

Clone the repository (or your fork) with its parts, then run the checks:

```sh
git clone --recurse-submodules https://github.com/Gooder24/karchi-os-headless-debian
cd karchi-os-headless-debian
make check
python3 .github/scripts/check-docs.py
```

`make check` takes seconds and needs no root. For a change to the installer's questions or the boot menu, also run
`make iso && make vm-test`. It takes about 10 minutes and needs QEMU with KVM and OVMF; the README explains it under
"Build and test".

## Parts

`parts/laptop-server` and `parts/reboot-when-idle` are separate repositories, Gooder24/laptop-server and
Gooder24/reboot-when-idle. Send their changes there. This repository only moves the submodule pointer.

## Pull requests

- Fill in every section of the pull request template, including the accessibility section. Where an item does not
  apply, write "not applicable" and the reason.
- Keep one change to one pull request.
- A change that adds or moves an accessibility barrier names it in the pull request and has an issue labeled
  `accessibility`.

## Reporting barriers

Use the [accessibility form](https://github.com/Gooder24/karchi-os-headless-debian/issues/new?template=accessibility.yml).
The section [Reporting accessibility barriers](ACCESSIBILITY.md#reporting-accessibility-barriers) in ACCESSIBILITY.md
says what to include.
