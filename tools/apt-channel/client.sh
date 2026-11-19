#!/bin/bash
# client.sh enable <archive-url> <public-key-file> | disable   (root)
set -euo pipefail
[[ $EUID == 0 ]] || { echo 'Run with sudo.' >&2; exit 1; }
case ${1:-} in
  enable)
    [[ $# == 3 && $2 =~ ^https?://[^[:space:]]+$ && -s $3 ]] || { echo 'usage: client.sh enable <archive-url> <public-key-file>' >&2; exit 2; }
    install -Dm644 "$3" /etc/apt/keyrings/karchi-headless.gpg
    cat > /etc/apt/sources.list.d/karchi-headless.sources <<EOF
Types: deb
URIs: ${2%/}/
Suites: karchi-headless
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/karchi-headless.gpg
EOF
    cat > /etc/apt/preferences.d/karchi-headless <<'EOF'
Package: karchi-headless laptop-server reboot-when-idle
Pin: release o=KarchiOS,n=karchi-headless
Pin-Priority: 600

Package: *
Pin: release o=KarchiOS
Pin-Priority: -1
EOF
    cat > /etc/apt/apt.conf.d/53karchi-channel <<'EOF'
// Add this archive to Debian's existing update policy; reboots remain reboot-when-idle's.
Unattended-Upgrade::Origins-Pattern {
  "origin=KarchiOS,codename=karchi-headless,label=KarchiOS Headless";
};
EOF
    echo 'KarchiOS channel enabled; run apt-get update.'
    ;;
  disable)
    rm -f /etc/apt/sources.list.d/karchi-headless.sources /etc/apt/preferences.d/karchi-headless \
      /etc/apt/apt.conf.d/53karchi-channel /etc/apt/keyrings/karchi-headless.gpg
    echo 'KarchiOS channel disabled; installed packages and Debian updates are unchanged.'
    ;;
  *) echo 'usage: client.sh enable <archive-url> <public-key-file> | disable' >&2; exit 2 ;;
esac
