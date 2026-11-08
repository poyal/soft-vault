#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="/opt/homebrew/bin:$PWD/.tools/flutter/bin:$PATH"
export LANG=en_US.UTF-8
fixture="${1:?Pass an absolute video fixture path}"
test -f "$fixture"
mkdir -p build/verification
check() {
  local label="$1"
  shift
  echo "Running $label"
  if flutter "$@" > "build/verification/$label.log" 2>&1; then
    echo "Passed $label"
  else
    tail -70 "build/verification/$label.log"
    return 1
  fi
}
check dependencies pub get
check analyze analyze --no-pub
check unit test --no-pub --exclude-tags 'load || stress'
names=(library catalog playback app-playback extended design codec ui-scenarios privacy native-stress)
targets=(library_flow catalog_flow playback_flow app_playback extended_flow design_parity codec_matrix scenario_flow privacy_flow stress_flow)
for i in "${!names[@]}"; do
  check "${names[$i]}-e2e" test "integration_test/${targets[$i]}_test.dart" -d macos --no-pub \
    "--dart-define=VIDEO_FIXTURE=$fixture" "--dart-define=REPO_ROOT=$PWD" \
    "--dart-define=DESIGN_ASSETS=$PWD/design/assets" "--dart-define=CODEC_FIXTURES=$PWD/.tools/fixtures/codecs"
done
check stress test test/stress_scenarios_test.dart --no-pub
export VAULT_FILE_COUNT=10000 VAULT_BENCH_LABEL=macos-10000
check performance test test/load_benchmark_test.dart test/catalog_benchmark_test.dart --no-pub --concurrency=1
for target in stress_flow ui_latency; do
  check "${target}-profile" drive -d macos --profile --no-pub \
    --driver=integration_test/performance_driver.dart "--target=integration_test/${target}_test.dart" \
    --dart-define=INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE=false "--dart-define=VIDEO_FIXTURE=$fixture"
done
check release build macos --release --no-pub
