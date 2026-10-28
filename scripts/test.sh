#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
mkdir -p .build/checks
swiftc -g Sources/Trace/Core/Statistics.swift Sources/Trace/Core/TextDraft.swift Sources/Trace/Core/StatisticsStore.swift Tests/CoreChecks.swift -o .build/checks/TraceCoreChecks
.build/checks/TraceCoreChecks
