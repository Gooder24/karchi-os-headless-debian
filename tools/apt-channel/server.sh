#!/bin/bash
# Enroll this Debian/Tailscale host as the archive publisher (root). Clients use client.sh separately.
set -euo pipefail
[[ $EUID == 0 ]] || { echo 'Run with sudo.' >&2; exit 1; }
here=$(dirname "$(realpath "$0")")
for command in git gpg gpgv dpkg-scanpackages dpkg-deb bwrap busybox; do command -v "$command" >/dev/null; done
busybox --list | grep -qx httpd
id karchi-apt >/dev/null 2>&1 || useradd --system --home-dir /var/lib/karchi-apt --shell /usr/sbin/nologin karchi-apt
install -d -o karchi-apt -g karchi-apt -m750 /var/lib/karchi-apt /var/cache/karchi-apt
install -d -o karchi-apt -g karchi-apt -m700 /var/lib/karchi-apt/gnupg
install -d -o karchi-apt -g karchi-apt -m755 /srv/karchi-apt
as_publisher() { runuser -u karchi-apt -- env HOME=/var/lib/karchi-apt GNUPGHOME=/var/lib/karchi-apt/gnupg "$@"; }
if [[ ! -e /var/lib/karchi-apt/source/.git ]]; then
  as_publisher git clone --recurse-submodules https://github.com/Gooder24/karchi-os-headless-debian.git /var/lib/karchi-apt/source
fi
fingerprint=$(as_publisher gpg --batch --with-colons --list-secret-keys | awk -F: '$1 == "fpr" {print $10; exit}')
if [[ -z $fingerprint ]]; then
  as_publisher gpg --batch --pinentry-mode loopback --passphrase '' --quick-generate-key 'KarchiOS Headless archive' ed25519 sign 0
  fingerprint=$(as_publisher gpg --batch --with-colons --list-secret-keys | awk -F: '$1 == "fpr" {print $10; exit}')
fi
as_publisher gpg --batch --export "$fingerprint" > /srv/karchi-apt/archive-keyring.gpg
chmod 644 /srv/karchi-apt/archive-keyring.gpg
cat > /etc/default/karchi-apt <<EOF
KARCHI_APT_STATE=/var/lib/karchi-apt
KARCHI_APT_WEB=/srv/karchi-apt
KARCHI_CACHE=/var/cache/karchi-apt
GNUPGHOME=/var/lib/karchi-apt/gnupg
KARCHI_APT_SIGNING_KEY=$fingerprint
EOF
for unit in karchi-apt-publish.service karchi-apt-publish.timer karchi-apt-http.service; do
  install -m644 "$here/$unit" "/etc/systemd/system/$unit"
done
systemctl daemon-reload
systemctl enable --now karchi-apt-http.service
systemctl start karchi-apt-publish.service
systemctl enable --now karchi-apt-publish.timer
echo "Signed channel: http://100.110.180.15:8770/ (public key fingerprint $fingerprint)"
