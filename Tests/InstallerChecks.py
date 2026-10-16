#!/usr/bin/env python3
"""Exercise the real installer in disposable folders, without UI or system installs.

Build once with scripts/build.sh first. The build stub copies that actual signed
app; open/xcode-select are recorded stubs, and process/tool preconditions are
controlled. HOME, real application folders, TCC and real apps are not changed.
"""
from pathlib import Path
import hashlib
import os
import plistlib
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / '.build/products/development/MCPlus.app'
assert APP.is_dir(), 'Run ./scripts/build.sh first'
checks = 0


def expect(value, message):
    global checks
    assert value, message
    checks += 1


with tempfile.TemporaryDirectory(prefix='mcplus-installer-checks-') as temporary:
    base = Path(temporary)
    source = base / 'Source with spaces'
    scripts = source / 'scripts'
    scripts.mkdir(parents=True)
    shutil.copy2(ROOT / 'Install.command', source / 'Install.command')
    shutil.copy2(ROOT / 'scripts/install.sh', scripts / 'install.sh')
    binaries = base / 'test-bin'
    binaries.mkdir()
    events = base / 'events.txt'

    def stub(path, text):
        path.write_text('#!/bin/zsh\nset -eu\n' + text + '\n')
        path.chmod(0o755)

    stub(scripts / 'build.sh', '''print "BUILD:$CHANNEL:$CODE_SIGN_IDENTITY" >> "$MCPLUS_TEST_EVENTS"
[[ "${MCPLUS_TEST_BUILD_FAILURE:-0}" != 1 ]] || exit 8
mkdir -p "$BUILD_ROOT/$CHANNEL"
if [[ "${MCPLUS_TEST_BAD_SIGNATURE:-0}" == 1 ]]; then
  mkdir -p "$BUILD_ROOT/$CHANNEL/MCPlus.app"
else
  /usr/bin/ditto "$MCPLUS_TEST_APP" "$BUILD_ROOT/$CHANNEL/MCPlus.app"
fi''')
    stub(binaries / 'pgrep', '[[ "${MCPLUS_TEST_RUNNING:-0}" == 1 ]]')
    stub(binaries / 'xcrun', '''[[ "${MCPLUS_TEST_MISSING_TOOLS:-0}" != 1 ]] || exit 1
exec /usr/bin/xcrun "$@"''')
    stub(binaries / 'sw_vers', '''if [[ "${MCPLUS_TEST_OLD_OS:-0}" == 1 ]]; then print '12.7'; else /usr/bin/sw_vers "$@"; fi''')
    stub(binaries / 'xcode-select', 'print "TOOLS:$*" >> "$MCPLUS_TEST_EVENTS"')
    stub(binaries / 'open', '''print "OPEN:$*" >> "$MCPLUS_TEST_EVENTS"
[[ "${MCPLUS_TEST_OPEN_FAILURE:-0}" != 1 ]]''')

    def event_lines():
        return events.read_text().splitlines() if events.exists() else []

    def run(destination, overrides=None, launch=False):
        environment = os.environ.copy()
        environment.update(PATH=str(binaries) + ':' + environment['PATH'],
                           MCPLUS_TEST_APP=str(APP), MCPLUS_TEST_EVENTS=str(events),
                           MCPLUS_INSTALL_ROOT=str(destination))
        environment.update(overrides or {})
        args = ['/bin/zsh', str(source / 'Install.command')]
        if not launch:
            args.append('--no-launch')
        return subprocess.run(args, cwd=base, env=environment, input='\n',
                              capture_output=True, text=True, timeout=60)

    def binary_hash(app):
        return hashlib.sha256((app / 'Contents/MacOS/MCPlus').read_bytes()).hexdigest()

    target = base / 'Applications with spaces'
    result = run(target)
    installed = target / 'MCPlus.app'
    expect(result.returncode == 0, result.stderr)
    expect(binary_hash(installed) == binary_hash(APP), 'Installed binary matches built app')
    expect('[3/3] 설치 완료' in result.stdout, 'Progress reaches completion')
    expect(not (target / '.mcplus-install.lock').exists(), 'Successful install releases lock')
    expect(not list(target.glob('.mcplus-install.*')), 'No staging directory left')
    expect(not any(e.startswith('OPEN:') for e in event_lines()), 'No-launch never opens UI')
    expect('BUILD:development:-' in event_lines(), 'Installer uses local development build')
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(installed)], check=True)

    marker = installed / 'Contents/Resources/previous-version-marker.txt'
    marker.write_text('Keep this previous app unchanged in backup')
    result = run(target)
    backups = list(target.glob('MCPlus Backups/*/MCPlus.app'))
    expect(result.returncode == 0, result.stderr)
    expect(len(backups) == 1, 'Previous app backed up once')
    expect((backups[0] / 'Contents/Resources/previous-version-marker.txt').read_text() == 'Keep this previous app unchanged in backup', 'Backup retains previous resources')
    expect(not marker.exists(), 'New app has clean resources')
    expect(binary_hash(installed) == binary_hash(APP), 'Replacement matches build')

    before = len(event_lines())
    other_root = base / 'other-app'
    other = other_root / 'MCPlus.app/Contents'
    other.mkdir(parents=True)
    original = plistlib.dumps({'CFBundleIdentifier': 'other.publisher.app'})
    (other / 'Info.plist').write_bytes(original)
    result = run(other_root)
    expect(result.returncode != 0, 'Different publisher app is rejected')
    expect((other / 'Info.plist').read_bytes() == original, 'Other app unchanged')
    expect(len(event_lines()) == before, 'Rejection happens before build')

    running_root = base / 'running'
    result = run(running_root, {'MCPLUS_TEST_RUNNING': '1'})
    expect(result.returncode != 0, 'Running app prevents install')
    expect(not running_root.exists(), 'Running app rejection changes no destination')

    result = run(base / 'missing-tools', {'MCPLUS_TEST_MISSING_TOOLS': '1'})
    expect(result.returncode != 0, 'Missing tools returns retry-needed state')
    expect(event_lines()[-1] == 'TOOLS:--install', 'Requests Apple tool installer through stub only')
    result = run(base / 'old-os', {'MCPLUS_TEST_OLD_OS': '1'})
    expect(result.returncode != 0 and 'macOS 13' in result.stderr, 'Unsupported OS rejected')

    linked_root = base / 'linked'
    linked_root.mkdir()
    (linked_root / 'MCPlus.app').symlink_to(installed)
    result = run(linked_root)
    expect(result.returncode != 0, 'Symlink destination rejected')
    expect((linked_root / 'MCPlus.app').is_symlink(), 'Symlink left intact')

    old_hash = binary_hash(installed)
    result = run(target, {'MCPLUS_TEST_BUILD_FAILURE': '1'})
    expect(result.returncode != 0, 'Build failure reported')
    expect(binary_hash(installed) == old_hash, 'Build failure keeps existing app')
    expect(len(list(target.glob('MCPlus Backups/*/MCPlus.app'))) == 1, 'Failure does not move old app')
    expect(not (target / '.mcplus-install.lock').exists(), 'Failure releases lock')

    # Clear the copied build so this case really contains an unsigned candidate.
    shutil.rmtree(source / '.build/products')
    result = run(target, {'MCPLUS_TEST_BAD_SIGNATURE': '1'})
    expect(result.returncode != 0, 'Unsigned candidate rejected')
    expect(binary_hash(installed) == old_hash, 'Signature failure keeps existing app')

    lock_root = base / 'active-lock'
    lock = lock_root / '.mcplus-install.lock'
    lock.mkdir(parents=True)
    (lock / 'pid').write_text(str(os.getpid()))
    result = run(lock_root)
    expect(result.returncode != 0, 'Live concurrent installer lock rejected')
    expect((lock / 'pid').read_text() == str(os.getpid()), 'Other process lock preserved')
    (lock / 'pid').write_text('99999999')
    result = run(lock_root)
    expect(result.returncode == 0, result.stderr)
    expect(not lock.exists(), 'Confirmed-dead installer lock recovered and released')

    launch_root = base / 'launch'
    result = run(launch_root, launch=True)
    expect(result.returncode == 0, result.stderr)
    expect(event_lines()[-1] == 'OPEN:' + str(launch_root / 'MCPlus.app'), 'Launch uses exact installed path through stub only')
    failure_root = base / 'launch-failure'
    result = run(failure_root, {'MCPLUS_TEST_OPEN_FAILURE': '1'}, launch=True)
    expect(result.returncode == 0 and (failure_root / 'MCPlus.app').is_dir(), 'Launch failure does not undo installation')
    expect('자동으로 열지 못했습니다' in result.stdout, 'Launch failure provides manual path')

print(f'Passed {checks} installer assertions. Real signed app copy and backup; controlled build/tool/process/launch stubs; no system app, real UI or permissions changed.')
