#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
fixture=${1:?Usage: script fixture-directory label [seconds] [filter] [cache-MiB] [loop]}
label=${2:-macos-candidate}
seconds=${3:-300}
filter=${4:-}
cache=${5:-64}
loop=${6:-false}
case "$label" in *[!A-Za-z0-9_-]*) echo 'Invalid label' >&2; exit 2;; esac
case "$cache" in 64) back=32;; 128) back=64;; *) echo 'Cache must be 64 or 128 MiB' >&2; exit 2;; esac
test -d "$fixture"
fixture=$(cd "$fixture" && pwd)
mkdir -p build/verification
export PATH="$PWD/.tools/flutter/bin:/opt/homebrew/bin:$PATH"
if flutter drive -d macos --profile --no-pub \
  --driver=integration_test/performance_driver.dart \
  --target=integration_test/playback_quality_test.dart \
  --dart-define=INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE=false \
  "--dart-define=PLAYBACK_FIXTURES=$fixture" \
  "--dart-define=PLAYBACK_LABEL=$label" \
  "--dart-define=PLAYBACK_SECONDS=$seconds" \
  "--dart-define=PLAYBACK_SEEKS=${PLAYBACK_SEEKS:-30}" \
  "--dart-define=PLAYBACK_DRAGS=${PLAYBACK_DRAGS:-1}" \
  "--dart-define=PLAYBACK_FILTER=$filter" \
  "--dart-define=PLAYBACK_CACHE_MB=$cache" \
  "--dart-define=PLAYBACK_BACK_CACHE_MB=$back" \
  "--dart-define=PLAYBACK_LOOP=$loop" \
  "--dart-define=PLAYBACK_CANDIDATE=${PLAYBACK_CANDIDATE:-true}" \
  >"build/verification/$label.log" 2>&1; then
  echo "Passed $label"
else
  tail -70 "build/verification/$label.log"
  exit 1
fi
