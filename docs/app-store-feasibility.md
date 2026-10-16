# Mac App Store feasibility

The current full-feature architecture has not passed App Sandbox requirements. Publishing this source does not imply it is eligible for the Mac App Store.

In a separate public-API-only capability probe on macOS 26.5.2, an ordinary build could read Dock accessibility children; the sandboxed build returned AXError -25204. Both reported AXIsProcessTrusted=true and could create a session event tap. Trust and event-tap creation alone did not establish permission to inspect or control other apps.

To reproduce locally, review `Tests/Distribution/SandboxProbe.swift`, then run `./scripts/check-sandbox.sh`. It creates ad-hoc signed public/sandbox probe bundles and local reports. Results depend on the machine, OS and actual permissions; no permission is granted by the script.

`CHANNEL=app-store-probe ./scripts/build.sh` compiles the product without Sparkle or its optional private AX window-ID bridge, with a sandbox entitlement. It is a capability experiment, not a working full-feature product for submission.

Official references:

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/): Mac App Store sandbox and public API requirements.
- [Protecting user data with App Sandbox](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox): incompatible cross-app assistive functionality.
- [Apple DTS discussion](https://developer.apple.com/forums/thread/789663): Accessibility API restrictions in sandboxed apps.

No sandbox escape, downloaded unsandboxed helper or review bypass is part of this project. A supported architecture must be established before representing the complete app as App Store ready.
