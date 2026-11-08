param([Parameter(Mandatory = $true)][string]$VideoFixture, [switch]$NormalUi)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$fixture = (Resolve-Path -LiteralPath $VideoFixture).Path
. (Join-Path $PSScriptRoot 'flutter-check.ps1')
Push-Location $repoRoot
try {
    $target = if ($NormalUi) { 'ui_latency_test' } else { 'stress_flow_test' }
    $label = if ($NormalUi) { 'native-ui-profile' } else { 'native-profile' }
    Invoke-FlutterCheck $label @(
        'drive', '-d', 'windows', '--profile', '--no-pub',
        '--driver=integration_test/performance_driver.dart',
        "--target=integration_test/$target.dart",
        '--dart-define=INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE=false',
        "--dart-define=VIDEO_FIXTURE=$fixture"
    )
} finally {
    Pop-Location
}
