param([Parameter(Mandatory = $true)][string]$VideoFixture)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$fixturePath = (Resolve-Path -LiteralPath $VideoFixture).Path
. (Join-Path $PSScriptRoot 'flutter-check.ps1')
Push-Location $repoRoot
try {
    New-Item -ItemType Directory -Force -Path build/verification | Out-Null
    $dart = Join-Path $repoRoot '.tools/flutter/bin/dart.bat'
    foreach ($entry in @(@('update_fixture','update_fixture'), @('update_helper','soft_vault_updater'))) {
        & $dart compile exe "tool/$($entry[0]).dart" -o "build/$($entry[1]).exe"
        if ($LASTEXITCODE -ne 0) { throw "Compilation failed: $($entry[0])" }
    }
    # Native tools write progress to stderr; judge their exit status, not the stream.
    $ErrorActionPreference = 'Continue'
    & $dart run tool/update_helper_smoke.dart *> build/verification/update-helper.log
    $helperExit = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($helperExit -ne 0) { throw 'Update install/rollback smoke failed; see update-helper.log' }
    Write-Output 'Passed 5 updater cases: install, rollback and invalid packages'
    Invoke-FlutterCheck 'shutdown-build' @('build','windows','--profile','--no-pub','-t','tool/shutdown_probe.dart')
    $ErrorActionPreference = 'Continue'
    & $dart run tool/measure_shutdown.dart build/windows/x64/runner/Profile/soft_vault.exe $fixturePath normal,repeated idle,playing,paused 3 candidate *> build/verification/shutdown.log
    $shutdownExit = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($shutdownExit -ne 0) { throw 'Shutdown probes failed; see shutdown.log' }
    Write-Output 'Passed 18 shutdown probes'
} finally {
    Pop-Location
}
