#!/bin/bash
# build-packages.sh <work> <out> <karchi-version> [<laptop-version> <reboot-version>]
# Shared by the offline ISO and the online channel, inside tools/sandbox.sh. No host root needed.
set -euo pipefail
repo=$(dirname "$(dirname "$(realpath "$0")")")
work=$1 out=$2 version=$3
mkdir -p "$work" "$out"
package=$(mktemp -d "$work/karchi-headless.XXXXXX")
mkdir -p "$package/DEBIAN"
cp -a "$repo/pkg/root/." "$package/"
sed "s/@VERSION@/$version/" "$repo/pkg/control" > "$package/DEBIAN/control"
if [[ $# == 5 ]]; then
  # One channel release must resolve to the tested parts, including when a part alone changed.
  sed -i "s/^Depends: laptop-server, reboot-when-idle,/Depends: laptop-server (= $4), reboot-when-idle (= $5),/" "$package/DEBIAN/control"
fi
install -m755 "$repo"/pkg/{preinst,postinst,postrm} "$package/DEBIAN/"
(cd "$package" && find etc -type f -printf '/%p\n' > DEBIAN/conffiles)
dpkg-deb --root-owner-group --build "$package" "$out/karchi-headless_${version}_all.deb"
for part in laptop-server reboot-when-idle; do
  args=()
  if [[ $# == 5 ]]; then
    [[ $part == laptop-server ]] && part_version=$4 || part_version=$5
    args+=("VERSION=$part_version")
  fi
  make -s -C "$repo/parts/$part" deb BUILD="$work/$part" OUT="$out" "${args[@]}"
done
