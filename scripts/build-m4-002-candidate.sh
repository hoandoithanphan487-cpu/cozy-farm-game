#!/usr/bin/env bash
# M4-002: Release build + zip candidate package + signing assessment.
# Does not modify source semantics; records build identity and hashes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/macos/CreekSprout/CreekSprout.xcodeproj"
SCHEME="CreekSprout"
DERIVED="/tmp/creeksprout-m4-002"
BUILD_ID="${BUILD_ID:-m4-002-candidate-macos-20260820T015427Z}"
RUN_ID="${RUN_ID:-20260820T015500Z}"
EVIDENCE="$ROOT/artifacts/acceptance/${BUILD_ID}/macos-arm64/${RUN_ID}"

mkdir -p "$EVIDENCE/build" "$EVIDENCE/logs"

LOG="$EVIDENCE/logs/xcodebuild-release.log"
echo "== M4-002 Release build ==" | tee "$LOG"
echo "started: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" | tee -a "$LOG"
xcodebuild -version | tee -a "$LOG"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$DERIVED" \
  build 2>&1 | tee -a "$LOG"

if grep -E ': warning:' "$LOG" | grep -v appintentsmetadata | grep -q .; then
  echo "FAIL: compiler warnings detected" >&2
  exit 1
fi
if grep -E ': error:' "$LOG" | grep -q .; then
  echo "FAIL: compiler errors detected" >&2
  exit 1
fi

APP="$DERIVED/Build/Products/Release/CreekSprout.app"
BIN="$APP/Contents/MacOS/CreekSprout"
test -d "$APP"
test -f "$BIN"

IDENTITY="$EVIDENCE/build/identity.txt"
{
  echo "candidate_build_id=$BUILD_ID"
  echo "run_id=$RUN_ID"
  echo "build_time_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "xcode_version=$(xcodebuild -version | tr '\n' ' ')"
  echo "configuration=Release"
  echo "destination=platform=macOS,arch=arm64"
  echo "derived_data_path=$DERIVED"
  echo "app_path=$APP"
  echo "bundle_short_version=$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist" 2>/dev/null || echo unknown)"
  echo "bundle_version=$(plutil -extract CFBundleVersion raw "$APP/Contents/Info.plist" 2>/dev/null || echo unknown)"
  echo "executable_file_info=$(file "$BIN")"
  echo "executable_sha256=$(shasum -a 256 "$BIN" | awk '{print $1}')"
  echo "app_bundle_sha256=$(shasum -a 256 "$BIN" | awk '{print $1}')"
} > "$IDENTITY"

# Package as zip (no DMG tooling; unzip is built-in for offline install evidence)
PKG_DIR="$EVIDENCE/build"
ZIP="$PKG_DIR/CreekSprout-m4-002-macos-arm64.zip"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
echo "package_zip=$ZIP" >> "$IDENTITY"
echo "package_sha256=$(shasum -a 256 "$ZIP" | awk '{print $1}')" >> "$IDENTITY"

# Signing assessment (adhoc / Sign to Run Locally — spctl rejected is expected)
{
  echo "=== codesign --verify --deep --strict ==="
  codesign --verify --deep --strict --verbose=2 "$APP" 2>&1 || true
  echo
  echo "=== spctl --assess --type execute ==="
  spctl --assess --type execute -vv "$APP" 2>&1 || true
} | tee "$EVIDENCE/logs/signing-assessment.txt"

echo "BUILD_OK app=$APP zip=$ZIP evidence=$EVIDENCE"
