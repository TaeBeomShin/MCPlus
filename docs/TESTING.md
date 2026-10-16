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

## Source installer

After a normal build, run `python3 Tests/InstallerChecks.py`. It runs the actual `Install.command` / `scripts/install.sh` against disposable directories with spaces. It copies the real ad-hoc signed app, verifies installation and backups, rejects other bundle IDs and symlinks, tests running-app and concurrent-installer refusal, recovers a confirmed-dead lock, and checks build/signature/launch failures. Build/tool/process checks and launch are controlled stubs. It does not change the user's Applications folder, invoke an actual developer-tool dialog, launch a real GUI or grant permissions.

For a full local build-and-copy smoke check without launch, set `MCPLUS_INSTALL_ROOT` to a disposable directory and run `/bin/zsh scripts/install.sh --no-launch`. Normal users launch `Install.command` from Finder; the default target is their own `~/Applications/MCPlus.app`. macOS quarantine handling and actual developer-tool installation dialogs remain environment-dependent; the README retains a manual build path.
