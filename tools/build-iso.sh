#!/bin/bash
# Builds the ISO, inside the sandbox: tools/sandbox.sh /repo/tools/build-iso.sh   (make iso)
# Debian's official netinst ISO stays as it is except for three things: the answers (iso/preseed.cfg) inside
# the installer's initrd, a boot menu with one entry, and /karchi with our scripts and the packages the
# netinst lacks. Result: /cache/out/<name>.iso, and next to it the installer's kernel and initrd for the test.
set -euo pipefail
source /repo/build.conf
netinst=/cache/dl/debian-$DEBIAN_VERSION-amd64-netinst.iso
version=$(date +%Y.%m.%d)
work=/cache/build
stage=$work/stage  # laid over the netinst's tree
pool=$stage/karchi/pool
apt=$work/apt
out=/cache/out/$OS_ID-$version-x86_64.iso

if [[ ! -e $netinst ]]; then
  name=${netinst##*/}
  # A release moves from the first address to the second when the next one comes out.
  for url in https://cdimage.debian.org/debian-cd/$DEBIAN_VERSION/amd64/iso-cd/$name \
             https://cdimage.debian.org/cdimage/archive/$DEBIAN_VERSION/amd64/iso-cd/$name; do
    /usr/lib/apt/apt-helper download-file "$url" "$netinst" "SHA256:$DEBIAN_ISO_SHA256" && break
  done
  [[ -e $netinst ]]
fi

rm -rf "$work"
mkdir -p "$pool" "$apt"/{lists,archives}/partial "$stage"/{install.amd,boot/grub} /cache/out
debconf-set-selections --checkonly /repo/iso/preseed.cfg

# --- our package: the files of pkg/root as they are, its dependencies are the system ------------------------
package=$work/karchi-headless
mkdir -p "$package/DEBIAN"
cp -a /repo/pkg/root/. "$package/"
sed "s/@VERSION@/$version/" /repo/pkg/control > "$package/DEBIAN/control"
(cd "$package" && find etc -type f -printf '/%p\n' > DEBIAN/conffiles)
dpkg-deb --root-owner-group --build "$package" "$pool/karchi-headless_${version}_all.deb" > /dev/null
depends=$(dpkg-deb -f "$pool"/karchi-headless_*.deb Depends | tr -d ,)

# --- the packages the netinst lacks -------------------------------------------------------------------------
# apt is asked what installing ours takes on a system that has nothing at all; what the netinst already
# carries in the very same version is then left out. Whatever the installed base turns out to be, apt on
# the target finds every dependency on the medium.
/usr/lib/apt/apt-helper download-file "https://pkgs.tailscale.com/stable/debian/$DEBIAN_SUITE.noarmor.gpg" "$apt/tailscale.gpg"
cat > "$apt/sources.list" << EOF
deb [signed-by=/usr/share/keyrings/debian-archive-keyring.pgp] http://deb.debian.org/debian $DEBIAN_SUITE main non-free-firmware
deb [signed-by=$apt/tailscale.gpg] https://pkgs.tailscale.com/stable/debian $DEBIAN_SUITE main
EOF
: > "$apt/status"
aptget() {
  apt-get -q -o Dir::State::status="$apt/status" -o Dir::State::lists="$apt/lists" \
    -o Dir::Cache::archives="$apt/archives" -o Dir::Etc::sourcelist="$apt/sources.list" \
    -o Dir::Etc::sourceparts=- "$@"
}
aptget update
# shellcheck disable=SC2086
aptget install -y --download-only $depends > "$work/apt-install.log"
xorriso -indev "$netinst" -find /pool -name '*.deb' 2> /dev/null | sed "s|.*/||; s|'$||" | sort -u > "$work/on-netinst"
for deb in "$apt"/archives/*.deb; do
  name=$(basename "$deb" | sed 's/_[0-9]*%3a/_/')  # apt keeps the epoch in the file name, a pool does not
  grep -qxF "$name" "$work/on-netinst" || cp "$deb" "$pool/$name"
done
(cd "$pool" && apt-ftparchive packages . > Packages)

# --- the installer --------------------------------------------------------------------------------------------
cp /repo/iso/{questions,late,templates} "$stage/karchi/"
xorriso -osirrox on -indev "$netinst" \
  -extract /install.amd/initrd.gz "$stage/install.amd/initrd.gz" \
  -extract /install.amd/vmlinuz "$work/vmlinuz" \
  -extract /boot/grub/grub.cfg "$work/grub.cfg" \
  -extract /md5sum.txt "$work/md5sum.txt" 2> /dev/null
chmod u+w "$stage/install.amd/initrd.gz" "$work"/{grub.cfg,md5sum.txt}
# The kernel unpacks every archive of an initrd in turn: ours adds /preseed.cfg, which the installer reads
# before its first question, and replaces two files of the installer so that it knows Slovak QWERTY: its table
# of keymaps, and the list of keyboards its question accepts. An answer that is not in that list debconf
# replaces with the default, "us", without a word, and the installed system then inherits "us" as well.
keymaps=usr/share/console-setup/pc105.ekmap.gz
templates=var/lib/dpkg/info/console-setup-udeb.templates
installer=$work/installer  # the installer's userland; its device nodes cannot be made here and are not needed
mkdir -p "$installer" "$work/initrd"/{"${keymaps%/*}","${templates%/*}"}
(cd "$installer" && zcat "$stage/install.amd/initrd.gz" | cpio --quiet -id -f 'dev/*')
cp /repo/iso/preseed.cfg "$work/initrd/"
{ zcat "$installer/$keymaps"; cat /repo/iso/sk-qwerty.ekmap; } | gzip -9 > "$work/initrd/$keymaps"
sed -e '/^Template: keyboard-configuration\/xkb-keymap$/,/^$/{' -e 's/^Choices-C: .*/&, sk(qwerty)/;t' \
  -e 's/^Choices[^:]*: .*/&, Slovak (QWERTY)/' -e '}' "$installer/$templates" > "$work/initrd/$templates"
# The installer's own tool, asked the way the installer asks: the last line for a key is the one that counts.
composed=$(sh "$installer/usr/bin/ckbcomp-mini" "-I$work/initrd/${keymaps%/*}" sk qwerty)
[[ $(grep '^keycode 21 =' <<< "$composed" | tail -1) == 'keycode 21 = +U+0079 '* && $(grep -c '^keycode' <<< "$composed") -gt 100 ]] \
  || { echo 'the keymap of the installer does not come out as Slovak QWERTY' >&2; exit 1; }
# The installer's keyboard step, run in its own userland on the files it will start with: the keyboard has to
# come out of it as the preseed asks.
cp -a "$work/initrd/." "$installer/"
asked=$(sed -n 's|^d-i keyboard-configuration/xkb-keymap select ||p' /repo/iso/preseed.cfg)
kept=$(chroot "$installer" sh -c '
  debconf-loadtemplate d-i /var/lib/dpkg/info/*.templates > /dev/null
  sh /lib/debian-installer-startup.d/S30initrd-preseed
  DEBIAN_FRONTEND=noninteractive /usr/share/console-setup/keyboard-configuration.config
  debconf-get keyboard-configuration/xkb-keymap') || true
[[ -n $asked && $kept == "$asked" ]] \
  || { echo "the installer turns the keyboard \"$asked\" of iso/preseed.cfg into \"$kept\"" >&2; exit 1; }
(cd "$work/initrd" && printf '%s\n' preseed.cfg "$keymaps" "$templates" | cpio --quiet -o -H newc -R 0:0 | gzip -9) >> "$stage/install.amd/initrd.gz"
# The netinst's menu up to its first entry (font, colours, theme), then our one entry.
{ sed '/^menuentry/,$d' "$work/grub.cfg"; cat /repo/iso/grub-entry.cfg; } > "$stage/boot/grub/grub.cfg"
(cd "$stage" && find . -type f | sort | xargs md5sum) > "$work/md5sum.ours"
{ grep -vFf <(sed 's/^[^ ]*//' "$work/md5sum.ours") "$work/md5sum.txt"; cat "$work/md5sum.ours"; } > "$stage/md5sum.txt"

rm -f "$out"
# "replay" writes the boot records (BIOS, EFI, the partition table for a USB stick) as the netinst has them.
xorriso -indev "$netinst" -outdev "$out" -boot_image any replay -map "$stage" / 2> "$work/xorriso.log" \
  || { cat "$work/xorriso.log"; exit 1; }
cp -f "$work/vmlinuz" "$stage/install.amd/initrd.gz" /cache/out/  # -f: the kernel comes out of the ISO read-only

echo "packages added to the netinst: $(ls "$pool"/*.deb | wc -l), $(du -sh "$pool" | cut -f1)"
ls "$pool" | sed -n 's/_.*//p' | paste -sd' ' | fold -s -w 110
echo "ISO: ~/.cache/karchi-os-headless-debian/out/${out##*/}, $(du -h "$out" | cut -f1)"
