param(
    [Parameter(Mandatory = $true)][string]$FixtureDirectory,
    [ValidatePattern('^[A-Za-z0-9_-]+$')][string]$Label = 'windows-candidate',
    [int]$Seconds = 300,
    [int]$Seeks = 30,
    [string]$Filter = '',
    [ValidateSet(64,128)][int]$CacheMiB = 64,
    [switch]$Loop,
    [switch]$Baseline
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$fixture = (Resolve-Path -LiteralPath $FixtureDirectory).Path
New-Item -ItemType Directory -Force (Join-Path $repo 'build/verification') | Out-Null
. (Join-Path $PSScriptRoot 'flutter-check.ps1')
$backCache = if ($CacheMiB -eq 128) { 64 } else { 32 }
$candidate = if ($Baseline) { 'false' } else { 'true' }
Push-Location $repo
try {
    Invoke-FlutterCheck $Label @(
        'drive', '-d', 'windows', '--profile', '--no-pub',
        '--driver=integration_test/performance_driver.dart',
        '--target=integration_test/playback_quality_test.dart',
        '--dart-define=INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE=false',
        "--dart-define=PLAYBACK_FIXTURES=$fixture",
        "--dart-define=PLAYBACK_LABEL=$Label",
        "--dart-define=PLAYBACK_SECONDS=$Seconds",
        "--dart-define=PLAYBACK_SEEKS=$Seeks",
        "--dart-define=PLAYBACK_FILTER=$Filter",
        "--dart-define=PLAYBACK_CACHE_MB=$CacheMiB",
        "--dart-define=PLAYBACK_BACK_CACHE_MB=$backCache",
        "--dart-define=PLAYBACK_CANDIDATE=$candidate"
        "--dart-define=PLAYBACK_LOOP=$($Loop.IsPresent.ToString().ToLowerInvariant())"
    )
} finally { Pop-Location }
