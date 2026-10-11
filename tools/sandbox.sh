#!/bin/bash
# Runs a command in a Debian userland without root: tools/sandbox.sh <command...>
# The build needs apt, dpkg-deb and xorriso, its check a clock that lies (faketime). The host is Arch and has
# none of them, and root on it asks for a password; the official debian:trixie-slim root filesystem under
# bubblewrap gives them all.
# Inside, the repository is /repo (read-only) and the cache is /cache.
set -euo pipefail
repo=$(dirname "$(dirname "$(realpath "$0")")")
cache=${KARCHI_CACHE:-$HOME/.cache/karchi-os-headless-debian}
root=$cache/sandbox
tools='xorriso cpio dpkg-dev apt-utils xz-utils ca-certificates faketime'

enter() {
  # CAP_SYS_CHROOT: the build runs the installer's keyboard step inside the installer's own userland.
  bwrap --unshare-user --uid 0 --gid 0 --unshare-pid --die-with-parent --cap-add CAP_SYS_CHROOT \
    --bind "$root" / --proc /proc --dev /dev --tmpfs /tmp \
    --ro-bind /etc/resolv.conf /etc/resolv.conf --ro-bind "$repo" /repo --bind "$cache" /cache \
    --setenv PATH /usr/sbin:/usr/bin:/sbin:/bin --setenv HOME /root --setenv LC_ALL C.UTF-8 \
    --setenv DEBIAN_FRONTEND noninteractive --chdir /repo "$@"
}

if [[ $(cat "$root/.ready" 2> /dev/null) != "$tools" ]]; then
  mkdir -p "$cache/dl" "$root"
  rootfs=$cache/dl/debian-trixie-slim-rootfs.tar.gz
  # Docker Hub names a layer by its SHA-256, which is checked here; whose image it is rests on TLS.
  [[ -e $rootfs ]] || python3 - "$rootfs" << 'EOF'
import hashlib, json, sys, urllib.request
repo, tag = 'library/debian', 'trixie-slim'
token = json.load(urllib.request.urlopen(
    f'https://auth.docker.io/token?service=registry.docker.io&scope=repository:{repo}:pull'))['token']
def get(path, accept='*/*'):
    return urllib.request.urlopen(urllib.request.Request(
        f'https://registry-1.docker.io/v2/{repo}/{path}', headers={'Authorization': f'Bearer {token}', 'Accept': accept}))
index = json.load(get(f'manifests/{tag}', 'application/vnd.oci.image.index.v1+json'))
digest = next(m['digest'] for m in index['manifests'] if m['platform']['architecture'] == 'amd64')
layer, = json.load(get(f'manifests/{digest}', 'application/vnd.oci.image.manifest.v1+json'))['layers']
data = get(f"blobs/{layer['digest']}").read()
assert 'sha256:' + hashlib.sha256(data).hexdigest() == layer['digest'], 'the layer does not match its digest'
open(sys.argv[1], 'wb').write(data)
EOF
  bsdtar -xpf "$rootfs" -C "$root" --exclude 'dev/*'
  # One user is all the sandbox has: apt cannot drop to _apt in it.
  echo 'APT::Sandbox::User "root"; APT::Install-Recommends "false"; Acquire::Retries "3";' \
    > "$root/etc/apt/apt.conf.d/99sandbox"
  enter apt-get -q update
  # shellcheck disable=SC2086
  enter apt-get -q install -y $tools
  echo "$tools" > "$root/.ready"
fi
enter "$@"
