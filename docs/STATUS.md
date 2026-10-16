# Development status

Version 0.2.0 is a source release, not a finished binary release. The original product's full feature equivalence and App Store distribution have not been established.

Before this source publication, the source was compiled for arm64 and x86_64, ad-hoc signatures were verified, and an unsigned universal Xcode Archive succeeded. Logic/input/controller assertions passed with Swift 5.8.1 and the Xcode 26.6 toolchain. On one Mac running macOS 26.5.2, disposable fixture tests exercised real close/minimize/hide/termination requests, duplicate/empty-title matching and confirmation cancellation. These observations do not establish physical-input, Intel hardware, other OS or final signed-app support.

The latest development GUI settings were visually reviewed; its own Accessibility permission and keyboard connection were not active. Native command-line tests used a separate authorized environment. Their trust must not be substituted for GUI permission.

Remaining release work includes final signed-app permission/input testing; real keyboard layouts, multiple displays and Spaces; supported hardware/OS coverage; login-at-start and signed updates; publisher metadata; real distribution signing and notarization. The current local bundle identifier is a development placeholder.

A public source repository does not resolve the Mac App Store's sandbox requirement. A supported full-feature Store architecture is not verified. No App Store submission or approval is implied by this source release.
