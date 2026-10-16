# MCPlus

An experimental macOS menu bar utility for managing windows in Mission Control. Built with Swift, AppKit and SwiftUI. 독립적으로 구현한 Mission Control 창 관리 앱의 개발용 소스입니다.

**Source release · development version 0.2.0.** This repository does not provide a signed, notarized or App Store approved application. Full physical keyboard/mouse, supported OS and hardware coverage is not complete. See [status and limitations](docs/STATUS.md).

## Build

Requirements: macOS 13 or later, Xcode or Apple Command Line Tools with Swift 5.8+, and internet access to fetch Sparkle. The deployment target is macOS 13; runtime observations so far are limited to one Mac on macOS 26.5.2.

```sh
./scripts/build.sh
./scripts/test.sh
```

The app is created at `.build/products/development/MCPlus.app` with a local ad-hoc signature. Sparkle 2.10.0 is downloaded from its official release and verified against a pinned SHA-256. No publisher account or distribution certificate is required for this local build.

Optional universal build:

```sh
ARCHS='arm64 x86_64' ./scripts/build.sh
```

For Xcode, first run `./scripts/fetch-sparkle.sh`, then open `MCPlus.xcodeproj`. The shared scheme is `MCPlus`. For local signing overrides, copy `Config/Local.example.xcconfig` to `Config/Local.xcconfig` and use your own team and bundle identifier. The shell build uses the `MCPLUS_BUNDLE_ID` environment variable instead. Do not commit local signing settings or credentials.

The shell script is the verified build entry point. `Package.swift` is also included, but SwiftPM packaging is not the verified app-bundle workflow.

## Run

1. Move your built app to the location where you intend to keep it and open it.
2. Grant it Accessibility permission in System Settings → Privacy & Security → Accessibility. A moved or rebuilt ad-hoc app may need to be approved again.
3. Open Mission Control and hover over a window thumbnail, or select one with Tab or the arrow keys.

Closing the settings window leaves the app in the menu bar. Use the menu bar to pause, reopen settings or quit. Start with disposable test windows; saving and cancellation are handled by the target application.

| Input | Action |
|---|---|
| × over the selected thumbnail | Request window close |
| Arrow keys | Select a window in that direction |
| Tab / Shift Tab | Next / previous thumbnail |
| ⌘W | Request selected window close |
| ⌥⌘W | Request all windows of the selected app close |
| ⌘M | Minimize selected window |
| Return | Open selected thumbnail |
| ⌘Q | Request normal app termination; Finder is excluded |
| ⌃⌘Q | Additional force-quit shortcut; unsaved changes may be lost |
| ⌘H | Hide selected app |
| ⌥⌘H | Hide other regular apps |

Shortcuts operate only while Mission Control is detected. Letter shortcuts use event characters with a modifier-independent fallback, rather than assuming QWERTY key positions. Actual keyboard-layout switching remains a manual verification item.

## Tests and implementation

- [Testing](docs/TESTING.md): assertion suite and disposable native fixture.
- [Architecture](docs/ARCHITECTURE.md): window identity, input routing and execution checks.
- [Status](docs/STATUS.md): verified scope and remaining release work.
- [Mac App Store feasibility](docs/app-store-feasibility.md): sandbox restrictions.

The app reads cross-app window metadata locally. It does not request screen recording permission. User-initiated diagnostic exports can contain open window titles; inspect those files before sharing them. Sparkle update checks remain unconfigured until a publisher supplies an HTTPS feed and signing public key.

## License and references

The project license is in [LICENSE](LICENSE); third-party notices are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Sparkle's license is retained with the resources.

This is an independent implementation inspired by the public functionality of [Mission Control Plus](https://www.fadel.io/missioncontrolplus). Static investigation used [REA](https://github.com/morluto/rea). Mission Control accessibility-tree investigation also consulted Hammerspoon's spaces module. The commercial application's binaries, assets, licensing code and exported disassembly are not part of this source release. This project is not affiliated with those projects or their authors.
