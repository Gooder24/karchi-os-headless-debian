# KarchiOS Headless (Debian)

Čo je kde, ako sa zostavuje a testuje: `README.md`. Sesterský projekt na Archu: `~/Work/karchi-os-headless`
(plán `~/.claude/plans/okej-vie-teda-z-lohova-tender-puppy.md`, časť B). Obe verzie majú robiť to isté;
čo sa zmení v jednej, patrí aj do druhej.

## Pravidlá práce v tomto repe
- Komentáre a hlášky v kóde sú po anglicky, dokumentácia po slovensky.
- Na hostiteľovi nič nepotrebuje root: zostavenie beží v pieskovisku (`tools/sandbox.sh`), testy v QEMU.
- Veľké súbory (stiahnutý netinst, pieskovisko, ISO, disky VM) sú v `~/.cache/karchi-os-headless-debian`, nie v repe.
- Hostiteľ má 15 GB pamäte a býva plný: pred `make vm-test` pozri `free -h` a nespúšťaj ho popri VM z `karchi-os`.

## Testing
- `make check` — statické kontroly a samotest na hostiteľovi (sekundy).
- `make iso && make vm-test` — brána: inštalácia bez siete do čistej VM, dva štarty s výpadkom napájania medzi nimi,
  `tests/check-installed.sh` a `SUPER + D` cez klávesnicu VM. Asi 10 minút.
- Zmena otázok inštalátora alebo ponuky štartu sa overuje aj ručne cez `tools/vm.py manual` (snímky obrazovky):
  brána odpovedá z príkazového riadku jadra a dialógy nevidí.
- Netriviálna logika má jednu spustiteľnú kontrolu (`--self-test`), nie sadu testov na funkciu.
