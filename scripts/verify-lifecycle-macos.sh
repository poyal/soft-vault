#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$PWD/.tools/flutter/bin:$PATH"
fixture="${1:?Pass an absolute video fixture path}"
mkdir -p build/verification
dart compile exe tool/update_fixture.dart -o build/update_fixture
dart compile exe tool/update_helper.dart -o build/soft_vault_updater
dart run tool/update_helper_smoke.dart > build/verification/update-helper.log 2>&1
echo 'Passed 5 updater cases'
flutter build macos --profile --no-pub -t tool/shutdown_probe.dart > build/verification/shutdown-build.log 2>&1
dart run tool/measure_shutdown.dart 'build/macos/Build/Products/Profile/Soft Vault.app/Contents/MacOS/Soft Vault' "$fixture" normal,repeated idle,playing,paused 3 candidate > build/verification/shutdown.log 2>&1
echo 'Passed 18 shutdown probes'
