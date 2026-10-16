# Testing

Run `./scripts/test.sh` on a Mac with the developer tools and a logged-in desktop session (the Finder-rejection test looks up the running Finder).

The current suite contains 30 window identity/navigation/coordinate assertions, 5,855 input/preference assertions including 100 repetitions per action, and 54 controller assertions. These counts are assertions, not independent end-to-end scenarios. Controller snapshots and overlays are controlled doubles; no physical input or real event tap is exercised. Preferences use disposable suites.

## Disposable native fixture

```sh
./scripts/build-fixture.sh
./scripts/build-integration-tests.sh
```

Launch `.build/MCPlusTestFixture.app`. It creates only its own disposable A/B windows and writes state to `.build/MCPlusTestFixture-state.json`. It does not read user documents. The native integration runner requires its own Accessibility-authorized execution environment; Terminal trust is not proof of trust for the MCPlus GUI.

With the fixture running, `.build/native-integration repeat 100` exercises close, close-all and minimize against fixture windows. `quit` and `forceQuit` terminate the fixture, so relaunch it between runs. `saveCancellationUI` presents real confirmation sheets: click Cancel in the fixture when the runner prompts, then it checks both windows and the process remain. Do not automate the fixture through actual user documents.

The `controller` mode requires fresh A/B windows followed by opening Mission Control. It tests value-input routing through the real controller/reader/executor under a fixture-only mutation gate. It does not test the physical event-tap callback or rendered overlay hit testing.

Reports are generated locally and ignored by git. They are not shipped as claims about the reader's machine. Full GUI permission, real keyboard/mouse input, layout switching, multi-display/Spaces/full-screen, login/relogin, signed updates and OS/hardware coverage remain manual release gates.
