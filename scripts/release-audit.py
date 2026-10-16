#!/usr/bin/env python3
"""Read-only artifact checks. Does not sign, launch, upload, or approve a release."""
import argparse
import base64
import datetime
import hashlib
import json
import os
import pathlib
import plistlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--channel', choices=['mac-app-store', 'direct'], default='mac-app-store')
parser.add_argument('--app', type=pathlib.Path)
args = parser.parse_args()
folder = 'app-store-probe' if args.channel == 'mac-app-store' else 'development'
app = (args.app or ROOT / '.build/products' / folder / 'MCPlus.app').resolve()
checks = []


def check(name, passed, detail):
    checks.append({'name': name, 'status': 'unverified' if passed is None else ('pass' if passed else 'fail'), 'detail': detail})


def run(*command):
    try:
        return subprocess.run(command, capture_output=True, timeout=30, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return None


def plist(path):
    try:
        return plistlib.loads(path.read_bytes())
    except (OSError, ValueError, plistlib.InvalidFileException):
        return {}


info = plist(app / 'Contents/Info.plist')
exe = app / 'Contents/MacOS' / str(info.get('CFBundleExecutable', 'MCPlus'))
check('bundle_present', bool(info) and exe.is_file(), 'App bundle and executable must exist.')
identifier = info.get('CFBundleIdentifier', '')
check('product_bundle_id', bool(re.fullmatch(r'[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+', identifier)) and not identifier.startswith(('local.', 'com.example.', 'YOUR_')), 'Local/example IDs must be replaced with an identifier owned by the publisher; account ownership is a manual gate.')
check('version_and_build', bool(info.get('CFBundleShortVersionString')) and bool(info.get('CFBundleVersion')), 'Presence only; does not verify App Store Connect version uniqueness.')
verify = run('codesign', '--verify', '--deep', '--strict', str(app))
check('signature_structure', verify is not None and verify.returncode == 0, 'codesign --verify --deep --strict; ad-hoc validity alone is insufficient for distribution.')
signature = run('codesign', '--display', '--verbose=4', str(app))
text = (signature.stderr + signature.stdout).decode(errors='replace') if signature else ''
if 'Signature=adhoc' in text:
    kind = 'ad-hoc'
elif 'Authority=Developer ID Application:' in text:
    kind = 'Developer ID Application'
elif 'Authority=Apple Distribution:' in text or 'Authority=3rd Party Mac Developer Application:' in text:
    kind = 'Mac App Store distribution'
else:
    kind = 'development-or-unverified'
expected = 'Mac App Store distribution' if args.channel == 'mac-app-store' else 'Developer ID Application'
check('distribution_identity', kind == expected, 'Detected signature category: ' + kind + '. Certificate holder names and Team IDs are not recorded.')
privacy = plist(app / 'Contents/Resources/PrivacyInfo.xcprivacy')
check('privacy_manifest_present', bool(privacy), 'Manifest parses; data-use declarations still require source/SDK review.')
bytes_ = exe.read_bytes() if exe.is_file() else b''
entitlements_result = run('codesign', '--display', '--entitlements', ':-', str(app))
try:
    entitlements = plistlib.loads(entitlements_result.stdout) if entitlements_result else {}
except (ValueError, plistlib.InvalidFileException):
    entitlements = {}
if args.channel == 'mac-app-store':
    check('app_sandbox', entitlements.get('com.apple.security.app-sandbox') is True, 'Checks the signed entitlement, not a source configuration flag.')
    check('known_private_bridge_excluded', bool(bytes_) and b'_AXUIElementGetWindow' not in bytes_, 'Narrow check for the known private bridge string only; not a complete public API audit.')
    check('sparkle_excluded', not (app / 'Contents/Frameworks/Sparkle.framework').exists(), 'The App Store build must use store updates.')
    probe_path = ROOT / 'reports/sandbox-capabilities.json'
    try:
        probe = json.loads(probe_path.read_text())
        error = probe.get('otherAppAXError')
        check('full_feature_sandbox_architecture', False if error != 0 else None, 'Separate public-API capability probe observed other-app AXError ' + str(error) + '. It is not this product binary\'s end-to-end validation. See docs/app-store-feasibility.md.')
    except (OSError, ValueError):
        check('full_feature_sandbox_architecture', None, 'No supported full-feature sandbox architecture is verified.')
else:
    check('hardened_runtime', 'runtime' in text and kind == 'Developer ID Application', 'A real Developer ID distribution signature with hardened runtime is required.')
    check('sparkle_embedded', (app / 'Contents/Frameworks/Sparkle.framework').is_dir(), 'Direct-distribution update framework must be embedded and included in signature validation.')
    from urllib.parse import urlparse
    feed = urlparse(str(info.get('SUFeedURL', '')))
    check('https_update_feed', feed.scheme == 'https' and bool(feed.hostname) and not feed.username and not feed.password, 'A real publisher-owned HTTPS feed is required; availability and ownership remain manual checks.')
    try:
        key_valid = len(base64.b64decode(info.get('SUPublicEDKey', ''), validate=True)) == 32
    except (ValueError, TypeError):
        key_valid = False
    check('update_public_key', key_valid, 'An Ed25519 public key must be embedded; no private keys are read or generated.')
xcode = run('xcodebuild', '-version')
check('full_xcode_available', xcode is not None and xcode.returncode == 0, 'Full Xcode is needed for the intended Archive/export workflow; this does not change xcode-select.')
manual = ['Full feature architecture and current Apple requirements/approval path', 'Latest signed GUI Accessibility permission and physical keyboard/mouse tests', 'Save-confirmation, multi-display/Spaces/fullscreen, supported OS/hardware and long-run performance', 'Login/relogin and signed update or store update validation', 'Publisher account, agreements, Bundle ID ownership, product metadata, support/privacy URLs and rights', 'Real distribution signing/export and channel-specific final validation; an unsigned archive alone is insufficient', 'Final artifact review and explicit upload/submission/publication authorization']
if args.channel == 'direct':
    manual.append('Notarization and stapled ticket validation for the exact distributed artifact')
report = {'recordedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'channel': args.channel, 'developerDirOverride': os.environ.get('DEVELOPER_DIR'), 'xcodeVersion': xcode.stdout.decode(errors='replace').strip() if xcode and xcode.returncode == 0 else None, 'artifact': str(app), 'executableSHA256': hashlib.sha256(bytes_).hexdigest() if bytes_ else None, 'checks': checks, 'manualGates': manual, 'result': 'blocked' if any(c['status'] != 'pass' for c in checks) else 'requires-manual-release-review', 'releaseApproved': False, 'scope': 'Read-only local artifact preflight, not App Store approval, notarization, or proof of feature completeness.'}
output = ROOT / 'reports' / ('release-audit-' + args.channel + '.json')
output.parent.mkdir(exist_ok=True)
output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
failed = [c['name'] for c in checks if c['status'] != 'pass']
print('Release audit:', report['result'], '; unresolved automated checks:', ', '.join(failed) or 'none')
print('Report:', output)
sys.exit(1 if failed else 0)
