param(
    [Parameter(Mandatory = $true)][string]$VideoFixture,
    [ValidateRange(1000,100000)][int]$FileCount = 10000
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$fixture = (Resolve-Path -LiteralPath $VideoFixture).Path
$flutter = Join-Path $repoRoot '.tools/flutter/bin/flutter.bat'
$savedCount = $env:VAULT_FILE_COUNT
$savedLabel = $env:VAULT_BENCH_LABEL
. (Join-Path $PSScriptRoot 'flutter-check.ps1')
Push-Location $repoRoot
try {
    New-Item -ItemType Directory -Force -Path build/verification | Out-Null
    Invoke-FlutterCheck 'stress' @('test', 'test/stress_scenarios_test.dart', '--no-pub')
    $env:VAULT_FILE_COUNT = "$FileCount"
    $env:VAULT_BENCH_LABEL = "optimized-$FileCount"
    Invoke-FlutterCheck 'performance' @('test', 'test/load_benchmark_test.dart', 'test/catalog_benchmark_test.dart', '--no-pub', '--concurrency=1')
    Invoke-FlutterCheck 'native-stress' @('test', 'integration_test/stress_flow_test.dart', '-d', 'windows', '--no-pub', "--dart-define=VIDEO_FIXTURE=$fixture")
} finally {
    $env:VAULT_FILE_COUNT = $savedCount
    $env:VAULT_BENCH_LABEL = $savedLabel
    Pop-Location
}
