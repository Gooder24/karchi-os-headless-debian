#!/bin/bash
# Runs over SSH inside a freshly installed test VM (as the test user, with passwordless sudo).
# Exit code 0 = the installation produced the system we expect, from the answers of tools/vm.py.
set -u
failed=0

# The budget of lightness: the first green run (11. 10. 2026) plus 15 %.
MAX_PACKAGES=281   # 244
MAX_DISK_MB=748    # 650
MAX_MEMORY_MB=281  # 244

check() {  # check "<description>" <command...>
  local name=$1 output
  shift
  # This script arrives on stdin; a command that read from it would swallow the remaining checks.
  if output=$("$@" 2>&1 < /dev/null); then
    printf 'ok    %s\n' "$name"
  else
    printf 'FAIL  %s\n' "$name"
    [[ -n $output ]] && sed 's/^/        /' <<< "$output"
    failed=1
  fi
}

not() { ! "$@"; }

no_failed_units() {
  local units
  units=$(systemctl --failed --no-legend --plain)
  [[ -z $units ]] || { echo "$units"; return 1; }
}

all_units() {  # all_units is-active|is-enabled <unit...>: systemctl alone is content when one of them is
  local state=$1 unit
  shift
  for unit; do
    systemctl "$state" --quiet "$unit" || { echo "$unit: $(systemctl "$state" "$unit")"; return 1; }
  done
}

swap_is_zram() {
  local devices
  devices=$(tail -n +2 /proc/swaps | cut -d' ' -f1)
  [[ $devices == /dev/zram0 ]] || { echo "swap on: ${devices:-nothing}"; return 1; }
}

root_locked() { [[ $(sudo passwd -S root | cut -d' ' -f2) == L ]]; }

wifi_from_installer() {
  local file=/var/lib/iwd/TestNet.psk
  [[ $(sudo stat -c %a "$file") == 600 ]] || { echo "$file: $(sudo stat -c %a "$file" 2>&1)"; return 1; }
  sudo grep -qx 'Passphrase=test-password' "$file" || { echo "$file does not hold the password"; return 1; }
  sudo iwctl known-networks list | grep -q TestNet || { echo 'iwd does not know the network'; return 1; }
}

tailscale_waits() {  # no key was given: logged out, and the unit that would use a key was skipped, not failed
  tailscale status 2>&1 | grep -q 'Logged out' || { tailscale status; return 1; }
  systemctl is-enabled --quiet karchi-tailscale-up || { echo 'karchi-tailscale-up is not enabled'; return 1; }
  [[ $(systemctl show -p ConditionResult --value karchi-tailscale-up) == no ]] || { echo 'the unit ran without a key'; return 1; }
  sudo test ! -e /etc/karchi/tailscale-authkey
}

lid_and_sleep() {
  local property value
  for property in HandleLidSwitch HandleLidSwitchExternalPower HandleLidSwitchDocked; do
    value=$(busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager "$property")
    [[ $value == 's "ignore"' ]] || { echo "$property is $value"; return 1; }
  done
  value=$(busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanSuspend)
  [[ $value != 's "yes"' ]] || { echo 'the machine could suspend'; return 1; }
}

display_off() {  # as karchi-display says, as the console says (0 = not blanked), and as the video driver says
  [[ $(karchi-display status) == off ]] || { echo "karchi-display status: $(karchi-display status)"; return 1; }
  [[ $(sudo sh -c 'setterm --term linux --blank < /dev/tty0') != 0 ]] || { echo 'the console is not blanked'; return 1; }
  # The console can count as blanked over an output that something has turned on again behind its back.
  sudo grep -q 'active=1' /sys/kernel/debug/dri/0/state && { echo 'the video output is on'; return 1; }
  return 0
}

keyboard() {  # what is set, and what the console really has: Y and Z as on QWERTY, the top row Slovak
  local keys
  grep -qx 'XKBLAYOUT="sk"' /etc/default/keyboard && grep -qx 'XKBVARIANT="qwerty"' /etc/default/keyboard \
    || { grep ^XKB /etc/default/keyboard; return 1; }
  grep -qx 'CODESET="Lat2"' /etc/default/console-setup || { grep ^CODESET /etc/default/console-setup; return 1; }
  keys=$(sudo dumpkeys)
  grep -Eq '^keycode +21 = \+?y ' <<< "$keys" && grep -Eq '^keycode +44 = \+?z ' <<< "$keys" \
    && grep -Eiq '^keycode +3 = \+?(lcaron|U\+013e) ' <<< "$keys" || { grep -E '^keycode +(3|21|44) =' <<< "$keys" | cut -c1-60; return 1; }
}

apt_sources() {  # nothing of the installation medium is left, and the network sources answer
  local left
  left=$(grep -rhE '^deb (cdrom|.*file:)' /etc/apt/sources.list /etc/apt/sources.list.d 2> /dev/null)
  [[ -z $left ]] || { echo "$left"; return 1; }
  not mountpoint -q /media/karchi || { echo '/media/karchi is still mounted'; return 1; }
  sudo apt-get -q update 2>&1 | grep -E '^(E|W|Err):' && return 1
  apt-cache policy tailscale | grep -q 'pkgs.tailscale.com' || { echo 'no Tailscale repository'; return 1; }
}

budget() {
  [[ $packages -le $MAX_PACKAGES && $disk -le $MAX_DISK_MB && $memory -le $MAX_MEMORY_MB ]] \
    || { echo "allowed: $MAX_PACKAGES packages, $MAX_DISK_MB MB on disk, $MAX_MEMORY_MB MB of memory"; return 1; }
}

timeout 120 systemctl is-system-running --wait > /dev/null
packages=$(dpkg-query -f '.\n' -W | wc -l)
disk=$(($(sudo btrfs filesystem usage -b / | sed -n 's/^ *Used:[^0-9]*\([0-9]*\).*/\1/p') / 1024 / 1024))
memory=$(free -m | awk '/^Mem:/ { print $3 }')

check 'the system is up, no failed service' no_failed_units
check 'the root is btrfs' grep -q ' / btrfs .*subvol=/@rootfs' /proc/mounts
check 'the EFI partition is mounted' mountpoint -q /boot/efi
check 'swap is compressed memory, no partition' swap_is_zram
check 'name of the machine (the default of the installer)' test "$(hostname)" = karchi-server
check 'time zone from our question' test "$(readlink -f /etc/localtime)" = /usr/share/zoneinfo/Europe/Prague
check 'root is locked, the user has sudo' root_locked
check 'services run' all_units is-active systemd-networkd systemd-resolved systemd-timesyncd iwd tailscaled keyd
check 'services start with the system' all_units is-enabled systemd-networkd systemd-resolved systemd-timesyncd iwd tailscaled keyd karchi-display-off karchi-tailscale-up
check 'the start does not wait for a cable' not systemctl is-enabled --quiet systemd-networkd-wait-online
check 'the lid does nothing, the machine never sleeps' lid_and_sleep
check 'Wi-Fi network from the installer is known to iwd' wifi_from_installer
check 'Tailscale waits for a login' tailscale_waits
check 'fastfetch greets at login' grep -q 'OS' <(bash -lic true 2> /dev/null)
check 'the display went off after the start' display_off
check 'the console keyboard is Slovak QWERTY, the font has its letters' keyboard
check 'the boot menu does not wait' sudo grep -q '^ *set timeout=0' /boot/grub/grub.cfg
check 'names resolve through systemd-resolved' getent hosts deb.debian.org
check 'packages come from the network: Debian and Tailscale answer' apt_sources
check 'karchi-doctor finds nothing broken' karchi-doctor
check "light: $packages packages, $disk MB on disk, $memory MB of memory" budget
printf '      started in: %s\n' "$(systemd-analyze | sed -n '1s/.*= //p')"
exit $failed
