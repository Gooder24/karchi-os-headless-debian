## What changes and why

<!-- A few sentences. Link the issue this closes, if there is one. -->

## Checks

- [ ] `make check` passes.
- [ ] `python3 .github/scripts/check-docs.py` passes.
- [ ] The installer's questions or the boot menu changed: `make iso && make vm-test` ran. Otherwise, write "not applicable" and why.

## Accessibility

<!-- See ACCESSIBILITY.md. Tick what applies; where an item does not apply, write "not applicable" and why. -->

- [ ] Documentation: headings follow each other, links say where they go, images have alternative text, and tables have header cells.
- [ ] Output (`karchi-doctor`, the installer's questions): the status is written in words, not only by color, and everything can be done with the keyboard.
- [ ] The installer's questions changed: checked with the keyboard only, and the new screens checked with `python3 -B tools/vm.py manual`.
- [ ] This change adds or moves an accessibility barrier: the barrier is described here and has an issue labeled `accessibility`.
