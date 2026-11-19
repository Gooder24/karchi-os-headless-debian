"""Exercise source revisions, the real signed APT format, failure gating and immutable publication."""
import hashlib
import importlib.util
import os
from pathlib import Path
import pwd
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('publish', ROOT / 'tools/apt-channel/publish.py')
channel = importlib.util.module_from_spec(spec)
spec.loader.exec_module(channel)


def command(*args, cwd=None, env=None):
    return subprocess.check_output(args, cwd=cwd, env=env, stderr=subprocess.STDOUT, text=True).strip()


def repository(path):
    path.mkdir()
    command('git', 'init', '-q', '-b', 'main', str(path))
    command('git', 'config', 'user.name', 'Channel test', cwd=path)
    command('git', 'config', 'user.email', 'test@localhost', cwd=path)
    for name in ('pkg/control', 'parts/laptop-server/payload', 'parts/reboot-when-idle/payload', 'tools/build-packages.sh'):
        f = path / name
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text('initial\n')
    commit(path, 'initial')


def commit(path, message):
    command('git', 'add', '.', cwd=path)
    command('git', 'commit', '-qm', message, cwd=path)


def package(web, work, version):
    control = work / ('pkg-' + version) / 'DEBIAN'
    control.mkdir(parents=True)
    (control / 'control').write_text(f'Package: karchi-headless\nVersion: {version}\nArchitecture: all\n'
                                   'Maintainer: Test <test@localhost>\nDescription: channel test\n')
    pool = web / 'pool'
    pool.mkdir(exist_ok=True, parents=True)
    command('dpkg-deb', '--root-owner-group', '--build', str(control.parent), str(pool / f'karchi-headless_{version}_all.deb'))


class ChannelTests(unittest.TestCase):
    def test_only_payload_changes_bump_versions_and_parts_are_pinned(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / 'source'
            repository(root)
            original = channel.versions(root)
            (root / 'README.md').write_text('documentation only\n')
            commit(root, 'docs')
            self.assertEqual(original, channel.versions(root))
            (root / 'parts/laptop-server/payload').write_text('new payload\n')
            commit(root, 'laptop change')
            changed = channel.versions(root)
            for name in ('karchi-headless', 'laptop-server'):
                command('dpkg', '--compare-versions', changed[name], 'gt', original[name])
            self.assertEqual(changed['reboot-when-idle'], original['reboot-when-idle'])

    def test_published_package_is_not_replaced_and_temp_files_are_not_served(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, destination = root / 'source', root / 'pool/version.deb'
            source.write_bytes(b'first complete package')
            channel.install_immutable(source, destination)
            source.write_bytes(b'a rebuilt package with a different timestamp')
            channel.install_immutable(source, destination)
            self.assertEqual(destination.read_bytes(), b'first complete package')
            self.assertEqual([p.name for p in destination.parent.iterdir()], ['version.deb'])

    def test_packaging_keeps_installer_defaults_and_channel_depends_on_exact_parts(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            command('bash', str(ROOT / 'tools/build-packages.sh'), str(root / 'build'), str(root / 'out'),
                    '1:0.999+gtest', '1:0.998+gtest', '1:0.997+gtest')
            meta = root / 'out/karchi-headless_1:0.999+gtest_all.deb'
            depends = command('dpkg-deb', '-f', str(meta), 'Depends')
            self.assertIn('laptop-server (= 1:0.998+gtest)', depends)
            self.assertIn('reboot-when-idle (= 1:0.997+gtest)', depends)
            for name, ver in (('laptop-server', '1:0.998+gtest'), ('reboot-when-idle', '1:0.997+gtest')):
                self.assertEqual(command('dpkg-deb', '-f', str(root / f'out/{name}_{ver}_all.deb'), 'Version'), ver)
            command('bash', str(ROOT / 'tools/build-packages.sh'), str(root / 'iso-build'), str(root / 'iso-out'), '2026.11.20')
            depends = command('dpkg-deb', '-f', str(root / 'iso-out/karchi-headless_2026.11.20_all.deb'), 'Depends')
            self.assertTrue(depends.startswith('laptop-server, reboot-when-idle,'))

    def test_real_apt_signature_old_indices_retained_and_failed_check_cannot_publish(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            web, home, state, cache = (root / p for p in ('web', 'gnupg', 'state', 'cache'))
            for p in (web, home, state, cache):
                p.mkdir()
            home.chmod(0o700)
            env = dict(os.environ, GNUPGHOME=str(home), KARCHI_APT_STATE=str(state), KARCHI_CACHE=str(cache), KARCHI_APT_WEB=str(web))
            command('gpg', '--batch', '--pinentry-mode', 'loopback', '--passphrase', '', '--quick-generate-key',
                    'Archive test', 'ed25519', 'sign', '0', env=env)
            keys = command('gpg', '--batch', '--with-colons', '--list-secret-keys', env=env)
            key = next(line.split(':')[9] for line in keys.splitlines() if line.startswith('fpr:'))
            public = subprocess.check_output(['gpg', '--batch', '--export', key], env=env)
            (web / 'archive-keyring.gpg').write_bytes(public)
            env['KARCHI_APT_SIGNING_KEY'] = key
            package(web, root, '1:0.1')
            with patch.dict(os.environ, env):
                channel.publish(web, key, {'karchi-headless': '1:0.1'}, 'fixture-first')
            dist = web / 'dists/karchi-headless'
            old = (dist / 'main/binary-amd64/Packages.gz').read_bytes()
            old_hash = hashlib.sha256(old).hexdigest()
            package(web, root, '1:0.2')
            with patch.dict(os.environ, env):
                channel.publish(web, key, {'karchi-headless': '1:0.2'}, 'fixture-second')
            self.assertEqual((dist / 'main/binary-amd64/by-hash/SHA256' / old_hash).read_bytes(), old)
            self.assertIn('Version: 1:0.1', (dist / 'main/binary-amd64/Packages').read_text())
            self.assertIn('Version: 1:0.2', (dist / 'main/binary-amd64/Packages').read_text())
            # Fresh isolated lists prove authenticity, not a cached index or an --allow-unauthenticated path.
            def apt_update(tag, public_key):
                apt = root / tag
                (apt / 'lists/partial').mkdir(parents=True)
                (apt / 'cache/archives/partial').mkdir(parents=True)
                (apt / 'status').touch()
                (apt / 'sources.list').write_text(f'deb [signed-by={public_key}] file:{web} karchi-headless main\n')
                return subprocess.run(['apt-get', '-o', 'Debug::NoLocking=1', '-o', 'APT::Update::Error-Mode=any',
                    '-o', 'APT::Sandbox::User=' + pwd.getpwuid(os.getuid()).pw_name,
                    '-o', 'Dir::Etc::parts=-', '-o', 'Dir::Etc::main=-', '-o', 'Dir::Etc::sourceparts=-',
                    '-o', 'Dir::Etc::sourcelist=' + str(apt / 'sources.list'), '-o', 'Dir::State::lists=' + str(apt / 'lists'),
                    '-o', 'Dir::State::status=' + str(apt / 'status'), '-o', 'Dir::Cache=' + str(apt / 'cache'), 'update'],
                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            good = apt_update('good-apt', web / 'archive-keyring.gpg')
            self.assertEqual(good.returncode, 0, good.stdout)
            command('gpg', '--batch', '--pinentry-mode', 'loopback', '--passphrase', '', '--quick-generate-key',
                    'Wrong archive', 'ed25519', 'sign', '0', env=env)
            wrong_key = root / 'wrong.gpg'
            wrong_key.write_bytes(subprocess.check_output(['gpg', '--batch', '--export', 'Wrong archive'], env=env))
            bad = apt_update('bad-apt', wrong_key)
            self.assertNotEqual(bad.returncode, 0, bad.stdout)
            self.assertRegex(bad.stdout, 'signature|NO_PUBKEY|Missing key')
            # Exercise the real publish entry point: test failure must happen before new packages/indices.
            source = root / 'source'
            repository(source)
            (source / 'Makefile').write_text('check:\n\tfalse\n')
            commit(source, 'a failing release')
            before = (dist / 'InRelease').read_bytes()
            with patch.object(channel, 'ROOT', source), patch.dict(os.environ, env):
                with self.assertRaises(subprocess.CalledProcessError):
                    channel.main()
            self.assertEqual((dist / 'InRelease').read_bytes(), before)


if __name__ == '__main__':
    unittest.main()
