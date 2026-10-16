#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p .build reports
swiftc -parse-as-library Sources/MCPlus/WindowLogic.swift Sources/MCPlus/InputRouter.swift Sources/MCPlus/Preferences.swift Sources/MCPlus/Accessibility.swift Sources/MCPlus/WindowActions.swift Sources/MCPlus/SelectionOverlay.swift Sources/MCPlus/MissionController.swift Tests/NativeIntegration.swift -o .build/native-integration
print "Built .build/native-integration; launch .build/MCPlusTestFixture.app before running it."
