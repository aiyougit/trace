#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
swift build -c release
APP="$PWD/dist/Trace.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
if [[ "${1:-}" == "--universal" ]]; then
    swift build -c release --arch x86_64 --scratch-path .build/intel
    swift build -c release --arch arm64 --scratch-path .build/apple-silicon
    lipo -create .build/apple-silicon/arm64-apple-macosx/release/Trace .build/intel/x86_64-apple-macosx/release/Trace -output "$APP/Contents/MacOS/Trace"
else
    cp .build/release/Trace "$APP/Contents/MacOS/Trace"
fi
cp Resources/Info.plist "$APP/Contents/Info.plist"
swift scripts/icon.swift "$APP/Contents/Resources"
# Reuse a configured code-signing certificate to preserve identity across updates.
# Ad-hoc builds bind privacy grants to the current binary and may need reauthorization.
TRACE_SIGNING_IDENTITY="${TRACE_CODESIGN_IDENTITY:--}"
codesign --force --deep --sign "$TRACE_SIGNING_IDENTITY" --identifier com.local.trace.desktop "$APP"
codesign --verify --deep --strict "$APP"
print "Built: $APP"
