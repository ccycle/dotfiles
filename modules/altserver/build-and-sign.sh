#!/usr/bin/env bash
# Archives an Xcode project/workspace and pushes the signed build to the
# paired iPhone via AltServer. Works from any forked-OSS repo; not tied to
# one specific app. Requires the iPhone to be on the same Wi-Fi as this Mac,
# and AltServer already signed into the dedicated sub Apple ID via its GUI
# (see modules/altserver/design.md) -- the installed binary exposes no
# Apple-ID/password CLI flags, only --udid, so credentials always come from
# AltServer's own Keychain-backed sign-in, never from this script.
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 <path-to-repo> <xcode-scheme> <device-udid>" >&2
  echo "  find the udid with: xcrun xctrace list devices" >&2
  exit 1
fi

REPO_PATH=$1
SCHEME=$2
DEVICE_UDID=$3

if ! command -v altserver >/dev/null 2>&1; then
  echo "altserver not found on PATH (is services.altserver.enable on and rebuilt?)" >&2
  exit 1
fi

WORKSPACE=$(find "$REPO_PATH" -maxdepth 2 -name '*.xcworkspace' -print -quit)
PROJECT=$(find "$REPO_PATH" -maxdepth 2 -name '*.xcodeproj' -print -quit)

if [[ -n $WORKSPACE ]]; then
  PROJECT_ARGS=(-workspace "$WORKSPACE")
elif [[ -n $PROJECT ]]; then
  PROJECT_ARGS=(-project "$PROJECT")
else
  echo "no .xcworkspace or .xcodeproj found under $REPO_PATH" >&2
  exit 1
fi

BUILD_DIR=$(mktemp -d)
trap 'rm -rf "$BUILD_DIR"' EXIT

ARCHIVE_PATH="$BUILD_DIR/$SCHEME.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
EXPORT_OPTIONS_PLIST="$BUILD_DIR/export-options.plist"

cat >"$EXPORT_OPTIONS_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>development</string>
  <key>signingStyle</key>
  <string>automatic</string>
</dict>
</plist>
EOF

xcodebuild archive \
  "${PROJECT_ARGS[@]}" \
  -scheme "$SCHEME" \
  -archivePath "$ARCHIVE_PATH"

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST"

IPA_PATH=$(find "$EXPORT_PATH" -maxdepth 1 -name '*.ipa' -print -quit)
if [[ -z $IPA_PATH ]]; then
  echo "export produced no .ipa in $EXPORT_PATH" >&2
  exit 1
fi

altserver --udid "$DEVICE_UDID" "$IPA_PATH"
