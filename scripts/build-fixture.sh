#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
NAME="${FIXTURE_NAME:-MCPlusTestFixture}"
BUNDLE_ID="${FIXTURE_BUNDLE_ID:-local.mcplus.test-fixture}"
PREFIX="${FIXTURE_PREFIX:-MCPlus Test}"
FIXTURE="$PWD/.build/$NAME.app"
mkdir -p "$FIXTURE/Contents/MacOS"
swiftc Tests/Fixture.swift -parse-as-library -o "$FIXTURE/Contents/MacOS/MCPlusTestFixture"
INFO="$FIXTURE/Contents/Info.plist"
# Recreate only this disposable app's own generated plist.
cat > "$INFO" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MCPlusTestFixture</string>
<key>CFBundleIdentifier</key><string>local.mcplus.test-fixture</string>
<key>CFBundleName</key><string>MCPlus Test Fixture</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
plutil -replace CFBundleIdentifier -string "$BUNDLE_ID" "$INFO"
plutil -insert MCPlusTestPrefix -string "$PREFIX" "$INFO"
plutil -insert MCPlusTestStatePath -string "$PWD/.build/$NAME-state.json" "$INFO"
codesign --force --sign - "$FIXTURE"
print "Built disposable test app: $FIXTURE"
