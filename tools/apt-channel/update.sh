#!/bin/bash
# The publisher's dedicated checkout is owned by karchi-apt. No root, force pull or local developer changes.
set -euo pipefail
source "${KARCHI_APT_CONFIG:-/etc/default/karchi-apt}"
export KARCHI_APT_STATE KARCHI_APT_WEB KARCHI_CACHE GNUPGHOME KARCHI_APT_SIGNING_KEY
exec 9> "$KARCHI_APT_STATE/publish.lock"
flock -n -E 75 9 || exit $?
cd "$KARCHI_APT_STATE/source"
[[ -z $(git status --porcelain --untracked-files=normal) ]] || { echo 'Publisher checkout is dirty' >&2; exit 1; }
git fetch origin main
git merge --ff-only origin/main
[[ $(git rev-parse HEAD) == "$(git rev-parse origin/main)" ]] || { echo 'Refusing unpublished local commits' >&2; exit 1; }
git submodule update --init --recursive
exec python3 tools/apt-channel/publish.py
