#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
CHANNEL="${CHANNEL:-development}"
BUILD_ROOT="${BUILD_ROOT:-$PWD/.build/products}"
IDENTITY="${CODE_SIGN_IDENTITY:--}"
ARCHS="${ARCHS:-$(uname -m)}"
APP="$BUILD_ROOT/$CHANNEL/MCPlus.app"
SDK_PATH="$(xcrun --show-sdk-path)"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$PWD/.build/objects"
SIGN_OPTIONS=(--options runtime)
[[ "$IDENTITY" != - ]] || SIGN_OPTIONS=(--options 0)
FLAGS=()
if [[ "$CHANNEL" == app-store-probe ]]; then
  FLAGS+=(-D APP_STORE)
else
  SPARKLE_ROOT="$(./scripts/fetch-sparkle.sh)"
  FLAGS+=(-F "$SPARKLE_ROOT" -framework Sparkle -Xlinker -rpath -Xlinker @executable_path/../Frameworks)
fi
BINS=()
for CPU in ${=ARCHS}; do
  BIN="$PWD/.build/objects/MCPlus-$CHANNEL-$CPU"
  swiftc -O -sdk "$SDK_PATH" -target "$CPU-apple-macosx13.0" "${FLAGS[@]}" -o "$BIN" Sources/MCPlus/*.swift
  BINS+=("$BIN")
done
if (( ${#BINS} > 1 )); then lipo -create "${BINS[@]}" -output "$APP/Contents/MacOS/MCPlus"; else cp "$BINS[1]" "$APP/Contents/MacOS/MCPlus"; fi
cp Resources/Info.plist "$APP/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string "${MCPLUS_BUNDLE_ID:-local.mcplus.app}" "$APP/Contents/Info.plist"
cp Resources/MCPlus.icns "$APP/Contents/Resources/MCPlus.icns"
if [[ -f Resources/PrivacyInfo.xcprivacy ]]; then cp Resources/PrivacyInfo.xcprivacy "$APP/Contents/Resources/"; fi
if [[ "$CHANNEL" == app-store-probe ]]; then
  # This is a capability probe, not a release-ready App Store edition.
  codesign --force --sign "$IDENTITY" --entitlements Tests/Distribution/Sandbox.entitlements "$APP"
else
  mkdir -p "$APP/Contents/Frameworks"
  ditto "$SPARKLE_ROOT/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
  cp "$SPARKLE_ROOT/LICENSE" "$APP/Contents/Resources/Sparkle-LICENSE.txt"
  F="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
  for COMPONENT in "$F/XPCServices/Downloader.xpc" "$F/XPCServices/Installer.xpc" "$F/Updater.app" "$F/Autoupdate"; do
    codesign --force --sign "$IDENTITY" "${SIGN_OPTIONS[@]}" "$COMPONENT"
  done
  codesign --force --sign "$IDENTITY" "${SIGN_OPTIONS[@]}" "$APP/Contents/Frameworks/Sparkle.framework"
  codesign --force --sign "$IDENTITY" "${SIGN_OPTIONS[@]}" "$APP"
fi
codesign --verify --deep --strict "$APP"
print "Built: $APP"
