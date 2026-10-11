# KarchiOS Headless (Debian)

Notebook ako server bez plochy, na Debiane 13. Jedno ISO, ktoré ho nainštaluje **bez siete**; robí to isté ako
`karchi-os-headless` na Archu (plán `~/.claude/plans/okej-vie-teda-z-lohova-tender-puppy.md`, časť B):

| Čo | Ako |
|---|---|
| Veko nič nerobí | `logind.conf.d`: `HandleLidSwitch*=ignore` |
| Stroj nikdy nespí | `sleep.conf.d`: `AllowSuspend=no`, `AllowHibernation=no` |
| Po zapnutí nabehne sám | disk bez šifrovania, ponuka štartu nečaká (`GRUB_TIMEOUT=0`), prihlasovací riadok na konzole |
| Displej je zhasnutý, `SUPER + D` ho prepína | `karchi-display on\|off\|toggle\|status`: vynútené zhasnutie konzoly, ktoré iný kláves nezruší; po štarte `karchi-display-off.service`, skratku drží `keyd` |
| Wi-Fi a kábel | `iwd` (sieť z inštalátora v `/var/lib/iwd`), kábel cez `systemd-networkd`, mená cez `systemd-resolved` |
| Tailscale | `tailscaled`; s auth kľúčom z inštalátora sa stroj pri prvom štarte prihlási sám (`--ssh`) |
| fastfetch pri prihlásení | `/etc/profile.d/karchi-fastfetch.sh`, na konzole aj cez SSH |
| Swap v pamäti | `systemd-zram-generator`, zstd |
| Klávesnica na konzole | slovenská QWERTY (`sk`, variant `qwerty`), písmo `Lat2`; platí pre každého vrátane roota |
| Kontrola zdravia | `karchi-doctor` |

Všetko uvedené je v jedinom balíku `karchi-headless` (`pkg/`): jeho závislosti sú celý systém nad základom
Debianu, jeho súbory sú nastavenia.

## Čo je kde

| Cesta | Čo |
|---|---|
| `pkg/control`, `pkg/root/` | balík `karchi-headless`; `root/` sa nainštaluje tak, ako je |
| `iso/preseed.cfg` | odpovede pre inštalátor Debianu (všetko okrem toho, čo sa pýta človeka) |
| `iso/sk-qwerty.ekmap` | slovenská QWERTY pre inštalátor: jeho vlastná tabuľka máp tento variant nemá |
| `iso/questions`, `iso/templates` | naše otázky: časové pásmo, Wi-Fi sieť a heslo, Tailscale auth key, disk |
| `iso/late` | posledný krok inštalátora: balík z média, potom `post-install` s odpoveďami |
| `iso/grub-entry.cfg` | jediná položka ponuky štartu |
| `tools/sandbox.sh` | debianový userland bez roota (bubblewrap), v ňom beží zostavenie |
| `tools/build-iso.sh` | zostavenie ISO |
| `tools/vm.py` | testovacia VM: inštalácia, štart, kontroly, klávesy, snímky |
| `tests/check-installed.sh` | kontroly nainštalovaného systému |
| `tests/check-medium.sh` | kontrola hotového ISO: všetko, čo si `iso/late` pýta, je na médiu, aj so zlými hodinami |
| `build.conf` | verzia a súčet netinst ISO, veľkosť testovacej VM |

Veľké súbory sú mimo repa v `~/.cache/karchi-os-headless-debian`: `dl/` (netinst, rootfs pieskoviska),
`sandbox/`, `build/`, `out/` (hotové ISO, jadro a initrd inštalátora pre test), `vm/` (disk testovacej VM, logy).

## Zostavenie a test

```
make check      # statické kontroly, sekundy
make iso        # ISO do ~/.cache/karchi-os-headless-debian/out; prvý raz stiahne asi 0,9 GB
make vm-test    # inštalácia bez siete do čistej VM, dva štarty s výpadkom napájania, kontroly
```

Nič z toho nepotrebuje root. Hostiteľ (Arch) nemá `apt`, `dpkg-deb` ani `xorriso`, preto zostavenie beží
v oficiálnom `debian:trixie-slim` pod bubblewrapom; ten si `tools/sandbox.sh` pri prvom behu stiahne sám.

### Ako ISO vzniká

Oficiálny netinst Debianu ostáva taký, aký je, až na tri veci:

1. Do initrd inštalátora sa pripojí `preseed.cfg` (inštalátor ho načíta pred prvou otázkou) a jeho tabuľka
   klávesových máp doplnená o slovenskú QWERTY.
2. Ponuka štartu má jednu položku a po 5 sekundách ju spustí sama.
3. Pribudne priečinok `/karchi`: naše skripty a `pool/` s balíkmi, ktoré netinst nemá (`iwd`, `systemd-resolved`,
   `keyd`, `fastfetch`, `systemd-zram-generator`, `tailscale` a ich závislosti) a balík `karchi-headless`.

Zoznam chýbajúcich balíkov sa neudržiava ručne: `apt` vypočíta, čo by inštalácia `karchi-headless` potrebovala
na úplne prázdnom systéme, a z toho sa vynechá všetko, čo netinst už nesie v tej istej verzii. Tailscale sa berie
z `pkgs.tailscale.com` (podpis overuje `apt`), ostatné z `deb.debian.org`.

Zavádzacie záznamy (BIOS, UEFI, tabuľka oddielov pre USB kľúč) prepíše `xorriso` v tej istej podobe, akú má netinst.

`make iso` končí kontrolou `tests/check-medium.sh`: z hotového ISO vyberie príkazy `apt`, ktoré spúšťa `iso/late`,
a spustí ich v pieskovisku s hodinami nastavenými na rok 2013. Musia prejsť len z média. Starý notebook
s vybitou batériou hodín štartuje v minulosti a `apt` vtedy odmietne súbor `Release` novší než jeho hodiny
(„not valid yet“); inštalátor z toho ukáže len `"sh /cdrom/karchi/late" failed with exit code 100`. Preto `late`
dátum nekontroluje (`Acquire::Check-Date=false`).

### Test vo VM

`make vm-test` spustí jadro inštalátora priamo a odpovede, ktoré by písal človek, mu dá na príkazový riadok
(`ANSWERS` v `tools/vm.py`). Inštalácia beží bez sieťovej karty a ISO je pripojené ako USB kľúč: kľúč je tiež
disk a inštalátor ho nesmie ponúknuť na prepísanie (keby ho nespoznal, zastane pri otázke na disk a brána padne).
Potom nainštalovaný disk naštartuje, cez SSH spustí `tests/check-installed.sh` a na obrazovke VM zmeria, že je
po štarte tmavá, že ju obyčajný kláves nerozsvieti a že ju `SUPER + D` rozsvieti a zhasne. Nakoniec vytrhne
napájanie a zopakuje to.

SSH a `sudo` bez hesla má len testovacia inštalácia: zapína ich `karchi/test-key=…` na príkazovom riadku jadra.

Kľúč je vo VM zapisovateľný ako skutočný (Ventoy z kľúča len na čítanie nenaštartuje), no zápisy idú do vrstvy,
ktorú QEMU po skončení zahodí (`snapshot=on`): súbor s ISO sa nezmení.

Namerané 11. 10. 2026: inštalácia 99 s, 246 balíkov, 659 MB na disku, 252 MB pamäte po štarte, štart za 3,7 s.
Strop v `tests/check-installed.sh` je prvý zelený beh + 15 %.

Dialógy inštalátora brána nevidí. Tie sa overujú ručne:

```
python3 -B tools/vm.py manual      # štart z kľúča s ISO cez jeho ponuku, dva disky, žiadne odpovede
python3 -B tools/vm.py manual ~/.cache/karchi-os-headless-debian/vm/ventoy.img   # to isté z obrazu Ventoy kľúča
python3 -B tools/vm.py shot        # snímka obrazovky (PNG), keď sa prestane meniť
python3 -B tools/vm.py key ret     # klávesy: ret, tab, down, alt-f2 (konzola inštalátora), alt-f4 (jeho log)
python3 -B tools/vm.py type text
```

Obraz Ventoy kľúča sa na hostiteľovi bez roota vyrobiť nedá. Vznikol v testovacej VM (`vm.py up` s prázdnym
obrazom ako druhým diskom, v nej `Ventoy2Disk.sh -I -g /dev/vdb` a ISO skopírované do `ISO/`).

## Inštalácia na skutočný stroj

ISO sa skopíruje na Ventoy kľúč medzi ostatné (`make usb DIR=/run/media/$USER/Ventoy/ISO`, nič sa nemaže), alebo
sa zapíše na vlastný kľúč. Stroj musí štartovať cez **UEFI**; Secure Boot môže ostať zapnutý (zavádzač Debianu
je podpísaný).

Inštalátor sa pýta v tomto poradí, potom už nikoho nepotrebuje:

1. názov počítača (predvolené `karchi-server`);
2. meno používateľa a heslo (root ostáva zamknutý, používateľ má `sudo`);
3. časové pásmo (predvolené `Europe/Bratislava`);
4. Wi-Fi sieť a heslo (prázdne = bez Wi-Fi);
5. Tailscale auth key (prázdne = prihlásiť neskôr ručne);
6. ktorý disk, len keď má stroj viac diskov. Kľúč, z ktorého inštalátor beží, v zozname nie je;
7. potvrdenie zápisu na disk. **Prepíše sa celý vybraný disk.** Predvolená odpoveď je „No“.

Na klávesnicu sa nepýta: je slovenská QWERTY už počas inštalácie (heslo sa teda píše tak isto ako potom na
konzole; číslice sú so Shiftom) aj v nainštalovanom systéme. Zoznam inštalátora ponúka len slovenskú QWERTZ, preto
je odpoveď daná vopred. Inú klávesnicu nastaví `sudo dpkg-reconfigure keyboard-configuration`.

Overené s Ventoy 1.1.17 (UEFI, GPT, „Boot in normal mode“).

Keď sa inštalátor zastaví s chybou, `Alt + F4` ukáže jeho log (späť `Alt + F1`); prečo, hovoria riadky s `E:`.

Po reštarte displej zhasne. `SUPER + D` ho rozsvieti, na konzole je prihlasovací riadok.

```
karchi-doctor                  # čo funguje a čo ešte treba urobiť ručne
sudo tailscale up --ssh        # ak inštalátor nedostal auth key
iwctl station wlan0 connect <sieť>     # Wi-Fi dodatočne
sudo apt update && sudo apt full-upgrade   # aktualizácie: Debian aj Tailscale
```

## Čo VM neoverí

Skutočné pripojenie na Wi-Fi, zhasnutie podsvietenia panela notebooku, spínač veka a prihlásenie auth kľúčom.
Na skutočnom stroji to ukáže `karchi-doctor`.

Displej: `karchi-display off` zhasne konzolu vynútene (`setterm --blank force`), takže ju stlačenie klávesu
nerozsvieti, a vypne podsvietenie (`bl_power`). Zápis do `/sys/class/graphics/fb0/blank` nestačí: zruší ho
prvý stlačený kláves. Keď grafický ovládač prevezme obrazovku až po štarte služby, stav obnoví pravidlo udev
(`90-karchi-display.rules`).

`getty@tty1` má vypnuté `TTYVTDisallocate`: systemd inak pri štarte getty čistí obrazovku aj s históriou, jadro
pri tom nanovo nastaví režim obrazovky a výstup sa zapne, hoci konzola ostáva „zhasnutá“. Pri štarte systému to
bol pretek s `karchi-display-off.service`, po odhlásení na konzole by sa displej rozsvietil vždy.
Test preto číta aj stav výstupu priamo z ovládača (`/sys/kernel/debug/dri/0/state`).

Známy strop: stroj sa po vypnutí sám nezapne, to je vec firmvéru. Všetko po stlačení tlačidla prebehne bez obsluhy.

## Rozdiely oproti verzii na Archu

- Inštalátor je debianový (`debian-installer`), nie vlastný: rozdelenie disku, firmvér podľa hardvéru a zavádzač
  rieši on. Preto funguje aj so zapnutým Secure Bootom a na inom hardvéri ako Intel.
- Zavádzač je GRUB, nie systemd-boot.
- Súborový systém je btrfs s jedným subvolume `@rootfs` (zvyk Debianu). `@home` sa dá oddeliť neskôr.
- Aktualizácie fungujú hneď (`apt`), verzia na Archu kanál aktualizácií nemá.
- Firmvér: `intel-microcode`, `firmware-intel-graphics` a `firmware-iwlwifi` sa inštalujú len tam, kde ten hardvér je.

## Zámerne nie vo verzii 1

Šifrovanie disku s odomykaním cez TPM; `sshd` s kľúčom pre agentov (dnu sa chodí cez Tailscale SSH); AI nástroje;
prah nabíjania batérie; preinštalovanie so zachovaním domova; automatické aktualizácie (`unattended-upgrades`);
štart cez BIOS.
