#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
mkdir -p .build/checks
swiftc Sources/Trace/Core/*.swift Sources/Trace/UI/*.swift Tests/RenderPreviews.swift -o .build/checks/RenderPreviews
.build/checks/RenderPreviews "$PWD/dist/previews"
