# KarchiOS Headless (Debian)

Notebook ako server bez plochy, na Debiane 13. Jedno ISO, ktoré ho nainštaluje **bez siete**; robí to isté ako
`karchi-os-headless` na Archu (plán `~/.claude/plans/okej-vie-teda-z-lohova-tender-puppy.md`, časť B):

| Čo | Ako |
|---|---|
| Veko nič nerobí | `logind.conf.d`: `HandleLidSwitch*=ignore` |
| Stroj nikdy nespí | `sleep.conf.d`: `AllowSuspend=no`, `AllowHibernation=no` |
| Po zapnutí nabehne sám | disk bez šifrovania, ponuka štartu nečaká (`GRUB_TIMEOUT=0`), prihlasovací riadok na konzole |
| Displej je zhasnutý, `SUPER + D` ho prepína | `karchi-display on\|off\|toggle\|status`, po štarte `karchi-display-off.service`, skratku drží `keyd` |
| Wi-Fi a kábel | `iwd` (sieť z inštalátora v `/var/lib/iwd`), kábel cez `systemd-networkd`, mená cez `systemd-resolved` |
| Tailscale | `tailscaled`; s auth kľúčom z inštalátora sa stroj pri prvom štarte prihlási sám (`--ssh`) |
| fastfetch pri prihlásení | `/etc/profile.d/karchi-fastfetch.sh`, na konzole aj cez SSH |
| Swap v pamäti | `systemd-zram-generator`, zstd |
| Kontrola zdravia | `karchi-doctor` |

Všetko uvedené je v jedinom balíku `karchi-headless` (`pkg/`): jeho závislosti sú celý systém nad základom
Debianu, jeho súbory sú nastavenia.

## Čo je kde

| Cesta | Čo |
|---|---|
| `pkg/control`, `pkg/root/` | balík `karchi-headless`; `root/` sa nainštaluje tak, ako je |
| `iso/preseed.cfg` | odpovede pre inštalátor Debianu (všetko okrem toho, čo sa pýta človeka) |
| `iso/questions`, `iso/templates` | naše štyri otázky: časové pásmo, Wi-Fi sieť a heslo, Tailscale auth key |
| `iso/late` | posledný krok inštalátora: balík z média, potom `post-install` s odpoveďami |
| `iso/grub-entry.cfg` | jediná položka ponuky štartu |
| `tools/sandbox.sh` | debianový userland bez roota (bubblewrap), v ňom beží zostavenie |
| `tools/build-iso.sh` | zostavenie ISO |
| `tools/vm.py` | testovacia VM: inštalácia, štart, kontroly, klávesy, snímky |
| `tests/check-installed.sh` | kontroly nainštalovaného systému |
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

1. Do initrd inštalátora sa pripojí `preseed.cfg`. Inštalátor ho načíta pred prvou otázkou.
2. Ponuka štartu má jednu položku a po 5 sekundách ju spustí sama.
3. Pribudne priečinok `/karchi`: naše skripty a `pool/` s balíkmi, ktoré netinst nemá (`iwd`, `systemd-resolved`,
   `keyd`, `fastfetch`, `systemd-zram-generator`, `tailscale` a ich závislosti) a balík `karchi-headless`.

Zoznam chýbajúcich balíkov sa neudržiava ručne: `apt` vypočíta, čo by inštalácia `karchi-headless` potrebovala
na úplne prázdnom systéme, a z toho sa vynechá všetko, čo netinst už nesie v tej istej verzii. Tailscale sa berie
z `pkgs.tailscale.com` (podpis overuje `apt`), ostatné z `deb.debian.org`.

Zavádzacie záznamy (BIOS, UEFI, tabuľka oddielov pre USB kľúč) prepíše `xorriso` v tej istej podobe, akú má netinst.

### Test vo VM

`make vm-test` spustí jadro inštalátora priamo a odpovede, ktoré by písal človek, mu dá na príkazový riadok
(`ANSWERS` v `tools/vm.py`). Inštalácia beží bez sieťovej karty. Potom nainštalovaný disk naštartuje, cez SSH
spustí `tests/check-installed.sh`, stlačí `SUPER + D` na klávesnici VM, vytrhne napájanie a zopakuje to.

SSH a `sudo` bez hesla má len testovacia inštalácia: zapína ich `karchi/test-key=…` na príkazovom riadku jadra.

Dialógy inštalátora brána nevidí. Tie sa overujú ručne:

```
python3 -B tools/vm.py manual      # štart z ponuky ISO, dva disky, žiadne odpovede
python3 -B tools/vm.py shot        # snímka obrazovky (PNG)
python3 -B tools/vm.py key ret     # klávesy: ret, tab, down, alt-f4 (alt-f4 = log inštalátora)
python3 -B tools/vm.py type text
```

## Inštalácia na skutočný stroj

ISO sa skopíruje na Ventoy kľúč medzi ostatné (`make usb DIR=/run/media/$USER/Ventoy/ISO`, nič sa nemaže), alebo
sa zapíše na vlastný kľúč. Stroj musí štartovať cez **UEFI**; Secure Boot môže ostať zapnutý (zavádzač Debianu
je podpísaný).

Inštalátor sa pýta v tomto poradí, potom už nikoho nepotrebuje:

1. klávesnica;
2. názov počítača (predvolené `karchi-server`);
3. meno používateľa a heslo (root ostáva zamknutý, používateľ má `sudo`);
4. časové pásmo (predvolené `Europe/Bratislava`);
5. Wi-Fi sieť a heslo (prázdne = bez Wi-Fi);
6. Tailscale auth key (prázdne = prihlásiť neskôr ručne);
7. ktorý disk (len keď ich vidí viac; kľúč, z ktorého štartuje, je medzi nimi);
8. potvrdenie zápisu na disk. **Prepíše sa celý vybraný disk.** Predvolená odpoveď je „No“.

Po reštarte displej zhasne. `SUPER + D` ho rozsvieti, na konzole je prihlasovací riadok.

```
karchi-doctor                  # čo funguje a čo ešte treba urobiť ručne
sudo tailscale up --ssh        # ak inštalátor nedostal auth key
iwctl station wlan0 connect <sieť>     # Wi-Fi dodatočne
sudo apt update && sudo apt full-upgrade   # aktualizácie: Debian aj Tailscale
```

## Čo VM neoverí

Skutočné pripojenie na Wi-Fi, zhasnutie panela notebooku, `SUPER + D` na skutočnej klávesnici, spínač veka
a prihlásenie auth kľúčom. Na skutočnom stroji to ukáže `karchi-doctor`; `karchi-display` preto píše do oboch
rozhraní (framebuffer aj podsvietenie).

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
