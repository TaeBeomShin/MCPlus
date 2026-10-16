#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
ROOT="$PWD/.build/distribution-probes"
mkdir -p "$ROOT" reports
swiftc -parse-as-library Tests/Distribution/SandboxProbe.swift -o "$ROOT/probe"
for KIND in public sandbox; do
  APP="$ROOT/$KIND.app"
  mkdir -p "$APP/Contents/MacOS"
  cp "$ROOT/probe" "$APP/Contents/MacOS/Probe"
  cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Probe</string>
<key>CFBundleIdentifier</key><string>local.mcplus.probe.$KIND</string>
<key>CFBundleName</key><string>MCPlus capability probe</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
  if [[ "$KIND" == sandbox ]]; then
    cat > "$ROOT/sandbox.entitlements" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict><key>com.apple.security.app-sandbox</key><true/></dict></plist>
PLIST
    codesign --force --sign - --entitlements "$ROOT/sandbox.entitlements" "$APP"
  else
    codesign --force --sign - "$APP"
  fi
  codesign --verify --strict "$APP"
  "$APP/Contents/MacOS/Probe" > "reports/$KIND-capabilities.json"
done
