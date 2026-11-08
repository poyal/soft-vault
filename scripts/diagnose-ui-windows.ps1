param([Parameter(Mandatory = $true)][string]$VideoFixture, [switch]$Trace)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$fixture = (Resolve-Path -LiteralPath $VideoFixture).Path
. (Join-Path $PSScriptRoot 'flutter-check.ps1')
Push-Location $repoRoot
try {
    $arguments = @(
        'drive', '-d', 'windows', '--profile', '--no-pub',
        '--driver=integration_test/performance_driver.dart',
        '--target=integration_test/bottleneck_diagnostics_test.dart',
        '--dart-define=INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE=false',
        "--dart-define=VIDEO_FIXTURE=$fixture"
    )
    if ($Trace) { $arguments += @('--trace-skia', '--dart-define=TRACE_DIAGNOSTICS=true') }
    Invoke-FlutterCheck 'bottleneck-diagnostics' $arguments
} finally {
    Pop-Location
}
