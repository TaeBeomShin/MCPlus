# Development status

Version 0.2.0-preview.1 provides a Developer ID-signed, Apple-notarized DMG as a development preview. The original product's full feature equivalence and App Store distribution have not been established.

Before this source publication, the source was compiled for arm64 and x86_64, ad-hoc signatures were verified, and an unsigned universal Xcode Archive succeeded. Logic/input/controller assertions passed with Swift 5.8.1 and the Xcode 26.6 toolchain. On one Mac running macOS 26.5.2, disposable fixture tests exercised real close/minimize/hide/termination requests, duplicate/empty-title matching and confirmation cancellation. These observations do not establish physical-input, Intel hardware, other OS or final signed-app support.

The latest development GUI settings were visually reviewed; its own Accessibility permission and keyboard connection were not active. Native command-line tests used a separate authorized environment. Their trust must not be substituted for GUI permission.

The direct-distribution preview uses `io.github.taebeomshin.mcplus` and a universal Intel/Apple Silicon binary. Its app and bundled helpers were signed with Developer ID, hardened runtime and secure timestamps. Apple accepted the exact DMG for notarization; its ticket was stapled, and Gatekeeper accepted the DMG and contained app. The signed executable also completed a command-line status smoke check.

Remaining release work includes final signed-GUI permission and physical-input testing; real keyboard layouts, multiple displays and Spaces; supported hardware/OS coverage; login-at-start and signed updates. The source build default remains the `local.mcplus.app` development identifier. Notarization and Gatekeeper acceptance do not establish feature equivalence or compatibility across supported systems.

A public source repository does not resolve the Mac App Store's sandbox requirement. A supported full-feature Store architecture is not verified. No App Store submission or approval is implied by this source release.
