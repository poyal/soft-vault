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
probe="$PWD/build/macos/Build/Products/Profile/Soft Vault.app/Contents/MacOS/Soft Vault"
python3 - "$probe" <<'PY'
import subprocess
import sys

for arguments, expected in [([], 0), (["incomplete"], 64)]:
    result = subprocess.run([sys.argv[1], *arguments], timeout=10)
    if result.returncode != expected:
        sys.exit(f"Probe with {arguments!r} exited with {result.returncode}, expected {expected}")
PY
dart run tool/measure_shutdown.dart "$probe" "$fixture" normal,repeated idle,playing,paused 3 candidate > build/verification/shutdown.log 2>&1
echo 'Passed 18 shutdown probes'
dart run tool/measure_shutdown.dart "$probe" "$fixture" application,repeated-application playing,seeking 3 application-quit > build/verification/application-quit.log 2>&1
echo 'Passed 12 application quit probes'
