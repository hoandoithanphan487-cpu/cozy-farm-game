#!/bin/sh
set -eu

require() {
  file=$1
  expected=$2
  if ! grep -Fq "$expected" "$file"; then
    printf 'Missing required text in %s: %s\n' "$file" "$expected" >&2
    exit 1
  fi
}

reject() {
  file=$1
  forbidden=$2
  if grep -Fq "$forbidden" "$file"; then
    printf 'Unexpected retired platform text in %s: %s\n' "$file" "$forbidden" >&2
    exit 1
  fi
}

plan=docs/game/platform-acceptance-plan.md
build=docs/game/build.md
ledger=docs/game/project-ledger.md
presets=export_presets.cfg

require "$plan" 'macOS arm64'
require "$plan" 'MacBook Air'
require "$plan" 'Apple M4'
require "$plan" 'M4 发布候选完整夹具'
require "$build" '| 发行目标 | macOS arm64 |'
require "$build" 'DEC-012'
require "$ledger" 'P0-006'
require "$ledger" 'DEC-012'
require "$presets" 'name="macOS arm64"'
reject "$presets" 'Windows x86-64'
reject "$presets" 'Windows Desktop'

printf 'PASS: macOS arm64 platform acceptance contract is internally consistent.\n'
