#!/usr/bin/env bash
# Picks the newest Xcode 27.x on the runner and makes sure it has the iOS 27.1 SDK,
# which Snaptrap needs for the iPhone Duo hinge APIs.
set -euo pipefail

# Prefer a final release; fall back to a release candidate or beta only if that's all there is.
all=$(ls -d /Applications/Xcode_27*.app 2>/dev/null | sort -V || true)
xcode=$(printf '%s\n' "$all" | grep -viE 'beta|release_candidate|_rc' | grep . | tail -1 || true)
[ -z "$xcode" ] && xcode=$(printf '%s\n' "$all" | grep . | tail -1 || true)
if [ -z "$xcode" ] && [ -d /Applications/Xcode.app ]; then xcode=/Applications/Xcode.app; fi
if [ -z "$xcode" ]; then
  echo "::error::No Xcode 27 found on this runner."
  ls -d /Applications/Xcode*.app || true
  exit 1
fi

sudo xcode-select -s "$xcode/Contents/Developer"
xcodebuild -version

sdk=$(xcrun --sdk iphoneos --show-sdk-version)
echo "iOS SDK $sdk"
if [ "$(printf '%s\n' 27.1 "$sdk" | sort -V | head -1)" != "27.1" ]; then
  echo "::error::Snaptrap needs the iOS 27.1 SDK (Xcode 27.1+), but this runner has iOS $sdk."
  exit 1
fi
