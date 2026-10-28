#!/bin/zsh
# Package an existing build without changing the application's signature.
set -euo pipefail
cd "${0:A:h}/.."
TRACE_PKG_APP="${1:-$PWD/dist/Trace.app}"
if [[ ! -f "$TRACE_PKG_APP/Contents/Info.plist" ]]; then
    print -u2 "Missing app: $TRACE_PKG_APP. Run ./scripts/build.sh --universal first."
    exit 1
fi
codesign --verify --deep --strict "$TRACE_PKG_APP"
TRACE_PKG_EXECUTABLE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$TRACE_PKG_APP/Contents/Info.plist")"
TRACE_PKG_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$TRACE_PKG_APP/Contents/Info.plist")"
if [[ ! "$TRACE_PKG_VERSION" =~ '^[0-9]+(\.[0-9]+){0,2}$' ]]; then
    print -u2 "Unsupported package version: $TRACE_PKG_VERSION"
    exit 1
fi
lipo "$TRACE_PKG_APP/Contents/MacOS/$TRACE_PKG_EXECUTABLE" -verify_arch arm64 x86_64
mkdir -p .build dist
TRACE_PKG_WORK="$(mktemp -d "$PWD/.build/pkg.XXXXXX")"
trap 'rm -rf "$TRACE_PKG_WORK"' EXIT
mkdir -p "$TRACE_PKG_WORK/root/Applications"
ditto "$TRACE_PKG_APP" "$TRACE_PKG_WORK/root/Applications/Trace.app"
pkgbuild --analyze --root "$TRACE_PKG_WORK/root" "$TRACE_PKG_WORK/components.plist"
# Prevent Installer from relocating the app to another matching development copy.
/usr/libexec/PlistBuddy -c 'Set :0:BundleIsRelocatable false' "$TRACE_PKG_WORK/components.plist"
pkgbuild --root "$TRACE_PKG_WORK/root" \
    --component-plist "$TRACE_PKG_WORK/components.plist" \
    --identifier com.local.trace.desktop.pkg \
    --version "$TRACE_PKG_VERSION" \
    --install-location / \
    --ownership recommended \
    "$TRACE_PKG_WORK/Trace-component.pkg"
sed "s/__TRACE_VERSION__/$TRACE_PKG_VERSION/g" Installer/Distribution.xml > "$TRACE_PKG_WORK/Distribution.xml"
TRACE_PKG_SIGN_ARGS=()
if [[ -n "${TRACE_INSTALLER_IDENTITY:-}" ]]; then
    TRACE_PKG_SIGN_ARGS=(--sign "$TRACE_INSTALLER_IDENTITY")
fi
TRACE_PKG_OUTPUT="$PWD/dist/Trace-$TRACE_PKG_VERSION-universal.pkg"
productbuild --distribution "$TRACE_PKG_WORK/Distribution.xml" \
    --resources "$PWD/Installer/Resources" \
    --package-path "$TRACE_PKG_WORK" \
    "${TRACE_PKG_SIGN_ARGS[@]}" \
    "$TRACE_PKG_OUTPUT"
print "Packaged: $TRACE_PKG_OUTPUT"
