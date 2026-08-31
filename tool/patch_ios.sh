#!/usr/bin/env bash
# Idempotent iOS config patcher.
#
# `flutter create --platforms=ios .` regenerates the iOS scaffold and MAY
# overwrite our committed ios/Runner/Info.plist and ios/Podfile with defaults.
# This script re-asserts the iOS settings the build and the App Store listing
# depend on, so both are correct regardless of what the scaffold produced:
#   1. App Transport Security -> NSAllowsArbitraryLoads (plain-HTTP IPTV).
#   2. Podfile platform + per-pod deployment target -> 15.0.
#   3. Xcode project IPHONEOS_DEPLOYMENT_TARGET -> 15.0.
#   4. PRODUCT_BUNDLE_IDENTIFIER -> com.dawnplayer.app (the App Store identity;
#      the scaffold default is com.example.<name>, which cannot be uploaded).
#   5. ITSAppUsesNonExemptEncryption -> false (export compliance).
#   6. TARGETED_DEVICE_FAMILY -> 1 (iPhone only; see the note at that step).
#
# Safe to run repeatedly and safe to run before or after `flutter create`.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLIST="$ROOT/ios/Runner/Info.plist"
PODFILE="$ROOT/ios/Podfile"
PBXPROJ="$ROOT/ios/Runner.xcodeproj/project.pbxproj"

echo "==> Patching Info.plist ATS: $PLIST"
if [ -f "$PLIST" ]; then
  if [ -x /usr/libexec/PlistBuddy ]; then
    # Remove any existing ATS block, then add the permissive one. PlistBuddy is
    # present on macOS runners; Delete is tolerant of a missing key.
    /usr/libexec/PlistBuddy -c "Delete :NSAppTransportSecurity" "$PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity dict" "$PLIST"
    /usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity:NSAllowsArbitraryLoads bool true" "$PLIST"
  elif grep -q "NSAllowsArbitraryLoads" "$PLIST"; then
    # Off-macOS (Windows dev box): can't rewrite the plist, but the committed
    # one already carries the ATS block — nothing to do.
    echo "    PlistBuddy unavailable; ATS block already present, skipping."
  else
    echo "!! PlistBuddy unavailable and $PLIST has no ATS block — fix it manually" >&2
    exit 1
  fi
else
  echo "!! $PLIST not found (run 'flutter create --platforms=ios .' first)" >&2
  exit 1
fi

echo "==> Patching Podfile platform: $PODFILE"
if [ -f "$PODFILE" ]; then
  if grep -qE "^\s*#?\s*platform :ios" "$PODFILE"; then
    # Replace whatever platform line exists (commented or not) with 15.0.
    sed -i.bak -E "s/^\s*#?\s*platform :ios.*/platform :ios, '15.0'/" "$PODFILE"
    rm -f "$PODFILE.bak"
  else
    # No platform line at all: prepend one.
    printf "platform :ios, '15.0'\n%s" "$(cat "$PODFILE")" > "$PODFILE"
  fi
else
  echo "!! $PODFILE not found" >&2
  exit 1
fi

echo "==> Patching Xcode deployment target: $PBXPROJ"
if [ -f "$PBXPROJ" ]; then
  sed -i.bak -E "s/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;/IPHONEOS_DEPLOYMENT_TARGET = 15.0;/g" "$PBXPROJ"
  rm -f "$PBXPROJ.bak"
else
  echo "!! $PBXPROJ not found (scaffold not generated yet)" >&2
  exit 1
fi

echo "==> Asserting bundle identifier: $PBXPROJ"
# The App Store identity. Must match Android's applicationId and the app
# registered in App Store Connect; RunnerTests keeps the .RunnerTests suffix.
sed -i.bak -E "s/PRODUCT_BUNDLE_IDENTIFIER = com\.example\.[A-Za-z0-9_]+/PRODUCT_BUNDLE_IDENTIFIER = com.dawnplayer.app/g" "$PBXPROJ"
rm -f "$PBXPROJ.bak"

echo "==> Asserting iPhone-only device family: $PBXPROJ"
# v1 is iPhone-only. Declaring iPad ("1,2") makes a 13-inch iPad screenshot set
# mandatory in App Store Connect and puts a phone-first layout (bottom nav bar,
# phone-width grids) in front of design review. Revisit when there is a real
# iPad layout to show.
sed -i.bak -E 's/TARGETED_DEVICE_FAMILY = "1,2";/TARGETED_DEVICE_FAMILY = "1";/g' "$PBXPROJ"
rm -f "$PBXPROJ.bak"

echo "==> Asserting export compliance: $PLIST"
if [ -x /usr/libexec/PlistBuddy ]; then
  # Set, or add if absent. Without it every upload stops to ask.
  /usr/libexec/PlistBuddy -c "Set :ITSAppUsesNonExemptEncryption false" "$PLIST" 2>/dev/null ||
    /usr/libexec/PlistBuddy -c "Add :ITSAppUsesNonExemptEncryption bool false" "$PLIST"
elif grep -q "ITSAppUsesNonExemptEncryption" "$PLIST"; then
  echo "    PlistBuddy unavailable; key already present, skipping."
else
  echo "!! PlistBuddy unavailable and $PLIST has no ITSAppUsesNonExemptEncryption" >&2
  exit 1
fi

echo "==> iOS config patched: ATS=on, target=15.0, id=com.dawnplayer.app"
