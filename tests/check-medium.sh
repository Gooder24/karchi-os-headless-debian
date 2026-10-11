#!/bin/bash
# What iso/late asks of apt, asked of the ISO just built, with the clock set back to 2013:
#   tools/sandbox.sh /repo/tests/check-medium.sh   (the last step of make iso)
# Every package late may install, with all it depends on, has to come from the medium alone, and at any
# date: a laptop whose clock battery has died starts in some past year, and apt then calls a newer Release
# file "not valid yet". The installer shows only "late failed with exit code 100" of that.
set -euo pipefail
source /repo/build.conf
iso=$(ls -t /cache/out/"$OS_ID"-*.iso | head -1)
work=/cache/build/medium
trap 'chmod -R u+w "$work" 2> /dev/null; rm -rf "$work"' EXIT  # the ISO's folders come out read-only
mkdir -p "$work"/{tree,etc/sources.list.d,etc/preferences.d,lists/partial,archives/partial}
: > "$work/status"  # nothing installed yet: the most apt can be asked for
xorriso -osirrox on -indev "$iso" -extract /dists "$work/tree/dists" -extract /pool "$work/tree/pool" \
  -extract /karchi "$work/tree/karchi" > /dev/null 2>&1
ln -sfn "$work/tree" /media/karchi  # where late mounts the medium in the new system

# late's own words, as they are on the ISO, so that this check cannot drift from it
late=$work/tree/karchi/late
grep '^deb ' "$late" > "$work/etc/sources.list.d/karchi-install.list"
eval "$(grep '^only=' "$late")"
packages="karchi-headless $(sed -n 's/.*packages="\$packages \([^"]*\)".*/\1/p' "$late" | paste -sd' ')"
[[ -s $work/etc/sources.list.d/karchi-install.list && -n ${only:-} && $packages == *firmware* ]] \
  || { echo 'check-medium: iso/late no longer reads the way this check expects' >&2; exit 1; }

aptget() {
  # shellcheck disable=SC2086  # $only is a list of options
  faketime -f '2013-01-01 00:00:00' apt-get -q -o Dir::Etc="$work/etc/" -o Dir::State::lists="$work/lists" \
    -o Dir::State::status="$work/status" -o Dir::Cache::archives="$work/archives" $only "$@"
}
# shellcheck disable=SC2086
{ aptget update && aptget install -y --download-only --no-install-recommends $packages; } > "$work/log" 2>&1 \
  || { grep '^E:' "$work/log" >&2 || tail -n 20 "$work/log" >&2; echo "check-medium: FAILED for ${iso##*/}" >&2; exit 1; }
echo "check-medium: ok, the medium alone gives $packages, whatever the clock says"
