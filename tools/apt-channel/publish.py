#!/usr/bin/env python3
"""Publish the three tested packages to a signed APT archive. Run through update.sh (which holds the lock)."""
import datetime as dt
import email.utils
import gzip
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PACKAGES = ('karchi-headless', 'laptop-server', 'reboot-when-idle')


def run(*args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def output(*args, **kwargs):
    return subprocess.check_output(args, text=True, **kwargs).strip()


def versions(root):
    """Only a payload/build-input change bumps a package. The main history must remain fast-forward."""
    result = {}
    for name, paths in (
        ('karchi-headless', ['pkg', 'parts', 'tools/build-packages.sh']),
        ('laptop-server', ['parts/laptop-server', 'tools/build-packages.sh']),
        ('reboot-when-idle', ['parts/reboot-when-idle', 'tools/build-packages.sh']),
    ):
        commit = output('git', 'log', '--first-parent', '-1', '--format=%H', '--', *paths, cwd=root)
        count = output('git', 'rev-list', '--count', commit, cwd=root)
        # Epoch 1 makes the channel newer than the old date/0.x packages. Counts, unlike clocks, only grow.
        result[name] = f'1:0.{count}+g{commit[:12]}'
    return result


def atomic(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix='.publish-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(name, 0o644)
        os.replace(name, path)
    finally:
        Path(name).unlink(missing_ok=True)


def install_immutable(source, destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    # Versions already published are reused, never rebuilt in place with different timestamps/bytes.
    if destination.exists():
        return
    with tempfile.NamedTemporaryFile(dir=destination.parent, prefix='.package-') as tmp:
        with source.open('rb') as incoming:
            shutil.copyfileobj(incoming, tmp)
        tmp.flush()
        os.fsync(tmp.fileno())
        os.chmod(tmp.name, 0o644)
        os.link(tmp.name, destination)


def publish(web, signing_key, source_versions, head):
    dist = web / 'dists/karchi-headless'
    index_dir = dist / 'main/binary-amd64'
    index_dir.mkdir(parents=True, exist_ok=True)
    packages = subprocess.check_output(['dpkg-scanpackages', '--multiversion', 'pool', '/dev/null'], cwd=web)
    indices = {'Packages': packages, 'Packages.gz': gzip.compress(packages, mtime=0)}
    hashes = []
    for filename, content in indices.items():
        digest = hashlib.sha256(content).hexdigest()
        # Keep every old index hash: clients that fetched the previous InRelease must still resolve it.
        atomic(index_dir / 'by-hash/SHA256' / digest, content)
        atomic(index_dir / filename, content)
        hashes.append(f' {digest} {len(content)} main/binary-amd64/{filename}')
    now = dt.datetime.now(dt.timezone.utc)
    date = email.utils.format_datetime(now, usegmt=True)
    expires = email.utils.format_datetime(now + dt.timedelta(days=7), usegmt=True)
    release = ('Origin: KarchiOS\nLabel: KarchiOS Headless\nSuite: karchi-headless\n'
               f'Codename: karchi-headless\nDate: {date}\nValid-Until: {expires}\n'
               'Architectures: amd64\nComponents: main\nAcquire-By-Hash: yes\n'
               'Description: Tested KarchiOS Headless packages\nSHA256:\n' + '\n'.join(hashes) + '\n').encode()
    # Stage and sign outside the served tree. InRelease is the final atomic commit of a publication.
    with tempfile.TemporaryDirectory(prefix='karchi-apt-sign-') as directory:
        staged = Path(directory)
        (staged / 'Release').write_bytes(release)
        run('gpg', '--batch', '--yes', '--local-user', signing_key, '--digest-algo', 'SHA256',
            '--clearsign', '--output', str(staged / 'InRelease'), str(staged / 'Release'))
        run('gpgv', '--keyring', str(web / 'archive-keyring.gpg'), str(staged / 'InRelease'))
        atomic(dist / 'Release', release)
        atomic(dist / 'InRelease', (staged / 'InRelease').read_bytes())
    atomic(web / 'release.json', (json.dumps({'checked_commit': head, 'versions': source_versions,
                                            'published': now.isoformat()}, indent=2) + '\n').encode())


def main():
    web = Path(os.environ['KARCHI_APT_WEB'])
    cache = Path(os.environ['KARCHI_CACHE'])
    state = Path(os.environ['KARCHI_APT_STATE'])
    signing_key = os.environ['KARCHI_APT_SIGNING_KEY']
    head = output('git', 'rev-parse', 'HEAD', cwd=ROOT)
    if output('git', 'status', '--porcelain', '--untracked-files=normal', cwd=ROOT):
        raise SystemExit('publish: refusing a dirty checkout')
    source_versions = versions(ROOT)
    previous_path = web / 'release.json'
    previous = json.loads(previous_path.read_text()) if previous_path.exists() else {}
    for name, old in previous.get('versions', {}).items():
        run('dpkg', '--compare-versions', source_versions[name], 'ge', old)
    checked = state / 'checked-commit'
    if not checked.exists() or checked.read_text().strip() != head:
        run('make', 'check', 'check-channel', cwd=ROOT)
        run('python3', '.github/scripts/check-docs.py', cwd=ROOT)
    required = {name: f'{name}_{source_versions[name]}_all.deb' for name in PACKAGES}
    if any(not (web / 'pool' / filename).exists() for filename in required.values()):
        with tempfile.TemporaryDirectory(prefix='apt-packages-', dir=cache) as directory:
            work = Path(directory)
            relative = work.relative_to(cache)
            run(str(ROOT / 'tools/sandbox.sh'), '/repo/tools/build-packages.sh',
                f'/cache/{relative}/build', f'/cache/{relative}/out',
                *(source_versions[name] for name in PACKAGES), cwd=ROOT)
            for name, filename in required.items():
                package = work / 'out' / filename
                assert output('dpkg-deb', '-f', str(package), 'Package') == name
                assert output('dpkg-deb', '-f', str(package), 'Version') == source_versions[name]
                install_immutable(package, web / 'pool' / filename)
    release = web / 'dists/karchi-headless/InRelease'
    stale = not release.exists() or dt.datetime.now().timestamp() - release.stat().st_mtime >= 86400
    if previous.get('versions') != source_versions or stale:
        publish(web, signing_key, source_versions, head)
        print('Published:', json.dumps(source_versions), flush=True)
    else:
        print('Already published; no package rebuild or repository change.', flush=True)
    atomic(checked, (head + '\n').encode())


if __name__ == '__main__':
    main()
