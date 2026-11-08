param([Parameter(Mandatory = $true)][string]$VideoFixture)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$fixturePath = (Resolve-Path -LiteralPath $VideoFixture).Path
if (-not (Test-Path -LiteralPath $fixturePath -PathType Leaf)) {
    throw 'VideoFixture must be a local video file.'
}
$flutterCommand = Join-Path $repoRoot '.tools/flutter/bin/flutter.bat'
if (-not (Test-Path -LiteralPath $flutterCommand)) {
    $flutterCommand = (Get-Command flutter -ErrorAction Stop).Source
}
. (Join-Path $PSScriptRoot 'flutter-check.ps1')
Push-Location $repoRoot
try {
    New-Item -ItemType Directory -Force -Path build/verification | Out-Null
    Invoke-FlutterCheck 'dependencies' @('pub', 'get')
    Invoke-FlutterCheck 'analyze' @('analyze', '--no-pub')
    Invoke-FlutterCheck 'unit' @('test', '--no-pub', '--exclude-tags', 'load || stress')
    # Separate processes avoid the Windows desktop test runner's second-app startup failure.
    Invoke-FlutterCheck 'library-e2e' @('test', 'integration_test/library_flow_test.dart', '-d', 'windows', '--no-pub', "--dart-define=VIDEO_FIXTURE=$fixturePath")
    Invoke-FlutterCheck 'catalog-e2e' @('test', 'integration_test/catalog_flow_test.dart', '-d', 'windows', '--no-pub', "--dart-define=DESIGN_ASSETS=$repoRoot/design/assets", "--dart-define=VIDEO_FIXTURE=$fixturePath")
    Invoke-FlutterCheck 'playback-e2e' @('test', 'integration_test/playback_flow_test.dart', '-d', 'windows', '--no-pub', "--dart-define=VIDEO_FIXTURE=$fixturePath")
    Invoke-FlutterCheck 'app-playback-e2e' @('test', 'integration_test/app_playback_test.dart', '-d', 'windows', '--no-pub', "--dart-define=VIDEO_FIXTURE=$fixturePath")
    Invoke-FlutterCheck 'extended-e2e' @('test', 'integration_test/extended_flow_test.dart', '-d', 'windows', '--no-pub', "--dart-define=VIDEO_FIXTURE=$fixturePath")
    Invoke-FlutterCheck 'design-e2e' @('test', 'integration_test/design_parity_test.dart', '-d', 'windows', '--no-pub', "--dart-define=REPO_ROOT=$repoRoot", "--dart-define=VIDEO_FIXTURE=$fixturePath")
    Invoke-FlutterCheck 'codec-e2e' @('test', 'integration_test/codec_matrix_test.dart', '-d', 'windows', '--no-pub', "--dart-define=CODEC_FIXTURES=$repoRoot/.tools/fixtures/codecs")
    Invoke-FlutterCheck 'ui-scenarios' @('test', 'integration_test/scenario_flow_test.dart', '-d', 'windows', '--no-pub', "--dart-define=VIDEO_FIXTURE=$fixturePath")
    Invoke-FlutterCheck 'privacy-e2e' @('test', 'integration_test/privacy_flow_test.dart', '-d', 'windows', '--no-pub', "--dart-define=VIDEO_FIXTURE=$fixturePath")
    & (Join-Path $PSScriptRoot 'verify-stress-windows.ps1') -VideoFixture $fixturePath
    & (Join-Path $PSScriptRoot 'verify-profile-windows.ps1') -VideoFixture $fixturePath
    & (Join-Path $PSScriptRoot 'verify-profile-windows.ps1') -VideoFixture $fixturePath -NormalUi
    Invoke-FlutterCheck 'release' @('build', 'windows', '--release', '--no-pub')
    & (Join-Path $PSScriptRoot 'build-test-report.ps1')
} finally {
    Pop-Location
}
