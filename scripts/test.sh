#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
TEST_DIR="$(mktemp -d /tmp/mcplus-tests.XXXXXX)"
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc Sources/MCPlus/WindowLogic.swift Tests/LogicChecks.swift -o "$TEST_DIR/logic"
"$TEST_DIR/logic"
swiftc Sources/MCPlus/WindowLogic.swift Sources/MCPlus/InputRouter.swift Sources/MCPlus/Preferences.swift Tests/InputChecks.swift -o "$TEST_DIR/input"
"$TEST_DIR/input"
swiftc -parse-as-library Sources/MCPlus/WindowLogic.swift Sources/MCPlus/InputRouter.swift Sources/MCPlus/Preferences.swift Sources/MCPlus/Accessibility.swift Sources/MCPlus/WindowActions.swift Sources/MCPlus/SelectionOverlay.swift Sources/MCPlus/MissionController.swift Tests/ControllerChecks.swift -o "$TEST_DIR/controller"
"$TEST_DIR/controller"
