#!/usr/bin/env python3
"""Test VMs for KarchiOS Headless (Debian). Nothing here needs root on the host.

  vm.py test            install the newest ISO into a fresh VM without network, unattended; boot the result and
                        check it, cut the power, boot and check again
  vm.py up | down       boot the installed test disk again (SSH on the test port) | stop it
  vm.py check           run tests/check-installed.sh and the checks of the screen against the running test VM
  vm.py ssh [command]   a shell, or one command, in the running test VM
  vm.py manual          start the ISO the way a real machine does: its own boot menu, two disks, no answers;
                        then by hand with key, type and shot. The installed disk starts with "up".
  vm.py key <combo...>  press keys in the running VM: ret, tab, down, meta_l-d, alt-f4
  vm.py type <text>     type text
  vm.py shot            PNG of the screen; prints its path
"""
import json
import os
import shutil
import socket
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
CONF = dict(line.split('=', 1) for line in (REPO / 'build.conf').read_text().splitlines()
            if '=' in line and not line.startswith('#'))
CACHE = Path(os.environ.get('KARCHI_CACHE', Path.home() / '.cache/karchi-os-headless-debian'))
OUT, VM = CACHE / 'out', CACHE / 'vm'
KEY = VM / 'key'
PORT = CONF['TEST_SSH_PORT']
OVMF_CODE = Path('/usr/share/edk2/x64/OVMF_CODE.4m.fd')
OVMF_VARS = Path('/usr/share/edk2/x64/OVMF_VARS.4m.fd')
USER = 'karchi'
GiB = 1024**3

# What the person at the keyboard would answer. The installer takes them from the kernel command line; a
# question that iso/preseed.cfg answers cannot be answered here, the file is read later and wins.
ANSWERS = {
    'priority': 'critical',
    'keyboard-configuration/xkb-keymap': 'us',
    'passwd/username': USER,
    'passwd/user-password': 'test',
    'passwd/user-password-again': 'test',
    'partman-auto/disk': '/dev/vda',
    'partman/confirm': 'true',
    'partman/confirm_nooverwrite': 'true',
    'karchi/timezone': 'Europe/Prague',
    'karchi/wifi-ssid': 'TestNet',
    'karchi/wifi-psk': 'test-password',
}


def die(msg):
    sys.exit(f'vm.py: {msg}')


def run(*cmd, check=True, **kw):
    return subprocess.run([str(c) for c in cmd], check=check, **kw)


# --- ssh ------------------------------------------------------------------------------------------------------

def public_key():
    VM.mkdir(parents=True, exist_ok=True)
    if not KEY.exists():
        run('ssh-keygen', '-q', '-t', 'ed25519', '-N', '', '-C', 'karchi-test', '-f', KEY)
    return KEY.with_suffix('.pub').read_text().split()[1]


def ssh(command=None, **kw):
    return run('ssh', '-i', KEY, '-p', PORT, '-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=/dev/null',
               '-o', 'LogLevel=ERROR', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=5', f'{USER}@127.0.0.1',
               *([command] if command else []), **kw)


def wait_ssh(timeout=240):
    deadline = time.time() + timeout
    while time.time() < deadline:
        if not pid():
            die('QEMU exited while waiting for SSH')
        if ssh('true', check=False, capture_output=True).returncode == 0:
            return
        time.sleep(2)
    shot()
    die(f'no SSH on port {PORT} after {timeout} s; the screen is in {VM}/screen.png')


# --- qemu -----------------------------------------------------------------------------------------------------

def pid():
    try:
        number = int((VM / 'test.pid').read_text())
        if b'qemu' in Path(f'/proc/{number}/cmdline').read_bytes():
            return number
    except (OSError, ValueError):
        pass
    return None


def qemu(log, *args, cache='writeback'):
    if pid():
        die(f'the test VM is already running (vm.py down, or kill {pid()})')
    available = int(next(line.split()[1] for line in open('/proc/meminfo') if line.startswith('MemAvailable'))) // 1024
    if available < int(CONF['TEST_RAM_MB']):
        print(f'vm.py: the host has {available} MB of memory available, the VM takes {CONF["TEST_RAM_MB"]}: it will swap')
    sock = VM / 'test.qmp'
    sock.unlink(missing_ok=True)
    run('qemu-system-x86_64', '-name', 'karchi-headless-debian-test', '-machine', 'q35,accel=kvm', '-cpu', 'host',
        '-smp', CONF['TEST_CPUS'], '-m', CONF['TEST_RAM_MB'], '-display', 'none', '-vga', 'std', '-daemonize',
        '-pidfile', VM / 'test.pid', '-qmp', f'unix:{sock},server=on,wait=off', '-serial', f'file:{VM / log}',
        '-device', 'virtio-rng-pci',
        '-drive', f'if=pflash,format=raw,unit=0,readonly=on,file={OVMF_CODE}',
        '-drive', f'if=pflash,format=raw,unit=1,file={VM / "test-vars.fd"}',
        '-drive', f'if=virtio,format=raw,cache={cache},file={VM / "test.img"}', *args)


def wait_exit(timeout, tick=None):
    deadline = time.time() + timeout
    while pid():
        if time.time() > deadline:
            return False
        if tick:
            tick()
        time.sleep(1)
    return True


def down():
    if pid():
        os.kill(pid(), 15)
        wait_exit(20)


class QMP:
    def __init__(self):
        self.sock = socket.socket(socket.AF_UNIX)
        self.sock.connect(str(VM / 'test.qmp'))
        self.file = self.sock.makefile('rw')
        self.sock.settimeout(10)  # the monitor talks to one at a time: to a second one it would never say a word
        try:
            self._reply()  # greeting
        except TimeoutError:
            die('the monitor of the VM does not answer: another vm.py holds it')
        self.sock.settimeout(None)
        self.cmd('qmp_capabilities')

    def _reply(self):
        while True:
            line = self.file.readline()
            if not line:
                raise ConnectionError('QMP connection closed')
            msg = json.loads(line)
            if 'event' not in msg:
                return msg

    def cmd(self, execute, **arguments):
        self.file.write(json.dumps({'execute': execute, 'arguments': arguments}) + '\n')
        self.file.flush()
        reply = self._reply()
        if 'error' in reply:
            raise RuntimeError(f"QMP {execute}: {reply['error']['desc']}")
        return reply.get('return')


QCODES = {'\n': 'ret', ' ': 'spc', '-': 'minus', '.': 'dot', '/': 'slash', '=': 'equal', ',': 'comma'}
SHIFTED = {'_': 'minus', ':': 'semicolon', '?': 'slash', '!': '1', '@': '2'}


def press(qmp, *combos, pause=0.3):
    for combo in combos:
        qmp.cmd('send-key', keys=[{'type': 'qcode', 'data': key} for key in combo.split('-')])
        time.sleep(pause)


def type_text(qmp, text):
    for ch in text:
        if ch.isupper() or ch in SHIFTED:
            press(qmp, 'shift-' + SHIFTED.get(ch, ch.lower()), pause=0.05)
        else:
            press(qmp, QCODES.get(ch, ch), pause=0.05)


def shot(qmp=None):
    png = VM / 'screen.png'
    (qmp or QMP()).cmd('screendump', filename=str(png), format='png')
    return png


# --- the test -------------------------------------------------------------------------------------------------

def newest_iso():
    isos = sorted(OUT.glob('*.iso'), key=lambda p: p.stat().st_mtime)
    return isos[-1] if isos else die(f'no ISO in {OUT}: make iso')


def fresh_disk(name, gigabytes):
    with open(VM / name, 'wb') as disk:
        disk.truncate(gigabytes * GiB)


def fresh_machine():
    down()
    VM.mkdir(parents=True, exist_ok=True)
    run('chattr', '+C', VM, check=False, capture_output=True)  # on btrfs: a disk image without copy-on-write
    fresh_disk('test.img', int(CONF['TEST_DISK_GB']))
    shutil.copy(OVMF_VARS, VM / 'test-vars.fd')


def install(iso):
    """Unattended, without network. The installer's kernel is started directly, to give it ANSWERS; the menu
    of the ISO itself is what "manual" goes through."""
    fresh_machine()
    answers = ANSWERS | {'karchi/test-key': public_key()}
    append = ' '.join(f'{key}={value}' for key, value in answers.items()) + ' --- quiet'
    started = time.time()
    qemu('install.log', '-kernel', OUT / 'vmlinuz', '-initrd', OUT / 'initrd.gz', '-append', append,
         '-cdrom', iso, '-nic', 'none', '-no-reboot', cache='unsafe')  # dpkg syncs all the time: three times faster
    if not wait_exit(45 * 60):
        shot()
        down()
        die(f'the installation did not end in 45 minutes; its last screen is in {VM}/screen.png')
    log = (VM / 'install.log').read_text(errors='replace')
    if 'KARCHI-INSTALL: OK' not in log:
        die(f'the installation failed:\n{log[-4000:]}')
    print(f'installed in {time.time() - started:.0f} s')


def up():
    qemu('boot.log', '-nic', f'user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:{PORT}-:22')
    wait_ssh()


def screen_lit(qmp):
    """Whether anything is on the screen: QEMU's std VGA shows a blanked console as all black."""
    ppm = VM / 'screen.ppm'
    qmp.cmd('screendump', filename=str(ppm))
    return any(ppm.read_bytes().split(b'\n', 3)[3])  # P6, width and height, 255, then the pixels


def display_keys():
    """The screen itself, not what karchi-display says about it: off after the start, no key but SUPER+D
    brings it back, SUPER+D turns it off again."""
    qmp = QMP()
    failed = 0
    for name, keys, lit in (('the display is off after the start', [], False),
                            ('a key press alone does not turn it on', ['shift'], False),
                            ('SUPER+D turns it on', ['meta_l-d'], True),
                            ('SUPER+D turns it off', ['meta_l-d'], False)):
        press(qmp, *keys, pause=1)
        state = ssh('karchi-display status', capture_output=True, text=True).stdout.strip()
        ok = screen_lit(qmp) == lit and state == ('on' if lit else 'off')
        print(f'{"ok  " if ok else "FAIL"}  {name}')
        failed |= not ok
    return failed


def check():
    with open(REPO / 'tests/check-installed.sh') as script:
        failed = ssh('bash -s', stdin=script, check=False).returncode
    return failed | display_keys()


def test():
    install(newest_iso())
    for start in ('first start', 'second start, after a power cut'):
        up()
        print(f'--- {start}')
        if check():
            die(f'{start}: checks failed; the VM is left running (vm.py ssh, vm.py down)')
        if start == 'first start':
            QMP().cmd('quit')  # the power cut: nothing is told to the system
            wait_exit(20)
    ssh('sudo poweroff', check=False)
    wait_exit(60) or down()
    print('PASS')


def manual():
    fresh_machine()
    fresh_disk('other.img', 2)  # with two disks the installer asks which one
    qemu('install.log', '-drive', f'if=virtio,format=raw,file={VM / "other.img"}', '-cdrom', newest_iso(),
         '-nic', 'none', '-no-reboot')
    print('started; vm.py shot, vm.py key ret, vm.py type <text>')


if __name__ == '__main__':
    sys.stdout.reconfigure(line_buffering=True)  # keep our lines in order with what ssh prints
    command, *rest = sys.argv[1:] or ['help']
    if command == 'test':
        test()
    elif command == 'up':
        up()
    elif command == 'down':
        down()
    elif command == 'check':
        sys.exit(check())
    elif command == 'ssh':
        sys.exit(ssh(' '.join(rest) or None, check=False).returncode)
    elif command == 'manual':
        manual()
    elif command == 'key':
        press(QMP(), *rest)
    elif command == 'type':
        type_text(QMP(), ' '.join(rest))
    elif command == 'shot':
        print(shot())
    else:
        print(__doc__)
