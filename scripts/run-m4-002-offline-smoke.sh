#!/usr/bin/env bash
# M4-002: offline install + VS-0 smoke orchestration (network off → install → drive → restore).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_ID="${BUILD_ID:-m4-002-candidate-macos-20260820T015427Z}"
RUN_ID="${RUN_ID:-20260820T015500Z}"
EVIDENCE="$ROOT/artifacts/acceptance/${BUILD_ID}/macos-arm64/${RUN_ID}"
ZIP="$EVIDENCE/build/CreekSprout-m4-002-macos-arm64.zip"
INSTALL_APP="/Applications/CreekSprout.app"
WIFI_IF="${WIFI_IF:-en0}"
SKIP_NETWORK="${SKIP_NETWORK:-0}"

mkdir -p "$EVIDENCE/offline" "$EVIDENCE/logs"

next_online_dry_log() {
  local dir="$1"
  if [[ ! -f "$dir/online-dry-run.log" ]]; then
    echo "$dir/online-dry-run.log"
    return
  fi
  local n=2
  while [[ -f "$dir/online-dry-run-r${n}.log" ]]; do
    n=$((n + 1))
  done
  echo "$dir/online-dry-run-r${n}.log"
}

wait_creeksprout_gone() {
  local i
  osascript -e 'tell application "CreekSprout" to quit' >/dev/null 2>&1 || true
  sleep 0.4
  killall CreekSprout >/dev/null 2>&1 || true
  for i in $(seq 1 25); do
    if ! pgrep -x CreekSprout >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.2
  done
  killall -9 CreekSprout >/dev/null 2>&1 || true
  sleep 0.3
}

record_network() {
  local dest="$1"
  {
    echo "timestamp_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "=== networksetup -getairportpower $WIFI_IF ==="
    networksetup -getairportpower "$WIFI_IF" 2>&1 || true
    echo
    echo "=== netstat -rn (default routes) ==="
    netstat -rn 2>&1 || true
    echo
    echo "=== route -n get default (if any) ==="
    route -n get default 2>&1 || true
  } > "$dest"
}

echo "== network before =="
record_network "$EVIDENCE/offline/network-before.txt"

if [[ "$SKIP_NETWORK" == "1" ]]; then
  echo "SKIP_NETWORK=1: keeping Wi-Fi on (online dry-run only; not valid for AC-3)"
  record_network "$EVIDENCE/offline/network-skipped-online.txt"
else
  echo "== disable Wi-Fi =="
  networksetup -setairportpower "$WIFI_IF" off
  sleep 2
  record_network "$EVIDENCE/offline/network-disabled.txt"

  if netstat -rn | awk '$1=="default"{found=1} END{exit !found}'; then
    echo "WARN: default route still present; recording honestly" | tee -a "$EVIDENCE/logs/offline-install.log"
  fi
fi

echo "== ensure CreekSprout is not running =="
wait_creeksprout_gone

echo "== install from zip (offline) =="
{
  echo "install_time_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "package=$ZIP"
  echo "target=$INSTALL_APP"
  echo "method=ditto unzip to /Applications"
} | tee "$EVIDENCE/logs/offline-install.log"

test -f "$ZIP"
rm -rf "$INSTALL_APP"
ditto -x -k "$ZIP" /Applications
test -d "$INSTALL_APP"

{
  echo "installed=yes"
  echo "install_path=$INSTALL_APP"
  ls -la "$INSTALL_APP/Contents/MacOS/" 2>&1
} >> "$EVIDENCE/logs/offline-install.log"

echo "== launch smoke (offline) =="
export M4_002_EVIDENCE="$EVIDENCE"
export M4_002_APP="$INSTALL_APP"
export M4_002_SAVE_DIR="$HOME/Library/Containers/com.fengyifan.CreekSprout/Data/Library/Application Support/CreekSprout"
export CREEKSPROUT_ROOT="$ROOT"

LAUNCH_LOG="$EVIDENCE/logs/offline-launch.txt"
{
  echo "launch_time_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo "open $INSTALL_APP"
} > "$LAUNCH_LOG"

set +e
if [[ "$SKIP_NETWORK" == "1" ]]; then
  DRY_LOG="$(next_online_dry_log "$EVIDENCE/logs")"
  echo "SKIP_NETWORK=1: keeping Wi-Fi on (online dry-run only; not valid for AC-3)" | tee "$DRY_LOG"
  echo "SKIP_NETWORK=1: also writing $DRY_LOG (not valid for AC-3)"
  python3 -u "$ROOT/scripts/drive-m4-002-vs0-smoke.py" 2>&1 | tee -a "$LAUNCH_LOG" | tee -a "$DRY_LOG"
  DRIVE_STATUS=${PIPESTATUS[0]}
else
  python3 -u "$ROOT/scripts/drive-m4-002-vs0-smoke.py" 2>&1 | tee -a "$LAUNCH_LOG"
  DRIVE_STATUS=${PIPESTATUS[0]}
fi
set -e

if [[ "$SKIP_NETWORK" == "1" ]]; then
  echo "== SKIP_NETWORK=1: Wi-Fi unchanged (not valid for AC-3) =="
else
  echo "== restore Wi-Fi =="
  networksetup -setairportpower "$WIFI_IF" on
  sleep 2
  record_network "$EVIDENCE/offline/network-restored.txt"
fi

if [[ "$DRIVE_STATUS" -ne 0 ]]; then
  echo "OFFLINE_SMOKE_FAIL drive_exit=$DRIVE_STATUS evidence=$EVIDENCE" >&2
  exit "$DRIVE_STATUS"
fi

echo "OFFLINE_SMOKE_OK evidence=$EVIDENCE"
