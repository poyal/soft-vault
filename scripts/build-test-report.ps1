$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$folder = Join-Path $repoRoot 'build/verification'
function Read-Result([string]$Relative, [switch]$Optional) {
    $path = Join-Path $repoRoot $Relative
    if (-not (Test-Path -LiteralPath $path)) {
        if ($Optional) { return $null }
        throw "Missing result: $Relative"
    }
    $parsed = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($item in $parsed) { $item }
}
$runs = @('unit','stress','performance','library-e2e','catalog-e2e','playback-e2e','app-playback-e2e','extended-e2e','design-e2e','codec-e2e','ui-scenarios','native-stress','privacy-e2e','library_filter_flow_test','playback_history_flow_test','settings_native_review_test','resize_profile_test','metadata_exchange_flow_test') | ForEach-Object {
    $path = Join-Path $folder "$_.log"
    $log = Get-Content -LiteralPath $path -Raw -Encoding UTF8
    $matches = [regex]::Matches($log, '\+(\d+)(?:\s+~(\d+))?: All tests passed!')
    if ($matches.Count -eq 0) { throw "No passing completion: $_" }
    [PSCustomObject]@{ Suite=$_; Tests=[int]$matches[$matches.Count-1].Groups[1].Value; Skipped=[int]$matches[$matches.Count-1].Groups[2].Value; Passed=$true; Log="$_.log"; Modified=(Get-Item $path).LastWriteTime.ToString('o') }
}
$report = [ordered]@{
    Generated = (Get-Date).ToString('o')
    Suites = @($runs)
    TestCount = ($runs | Measure-Object Tests -Sum).Sum
    UiScenarios = @(Read-Result 'build/e2e/scenario-results.json')
    Privacy = @(Read-Result 'build/e2e/privacy-results.json')
    Stress = @(Read-Result 'build/verification/stress-results.json')
    NativeStress = @(Read-Result 'build/e2e/stress-results.json')
    ProfileStress = @(Read-Result 'build/e2e/stress-profile-results.json' -Optional)
    ProfileUi = Read-Result 'build/e2e/ui-profile-results.json' -Optional
    Hardware = Read-Result 'build/verification/hardware.json' -Optional
    Resources = @('release-before-update','debug-e2e-active','profile-live-normal-ui','release-latest','profile-native-ui-after-render-fix','release-after-render-fix' | ForEach-Object {
        $entry = Read-Result "build/verification/resources-$_.json" -Optional
        if ($entry) { $entry.Summary }
    })
    Baseline1000 = Read-Result 'build/verification/load-baseline.json' -Optional
    Optimized1000 = Read-Result 'build/verification/load-optimized-1000.json' -Optional
    Load10000 = Read-Result 'build/verification/load-optimized-10000.json'
    Catalog50000 = Read-Result 'build/verification/catalog-50000.json'
    Shutdown = @(Read-Result 'build/shutdown-probes/candidate.json')
    Limits = 'Windows on this PC. Native UI suites use debug and profile builds; timings are not release FPS. Optional baseline and resource samples are historical context, not current candidate measurements. Scan fixtures are tiny unique files, not a 10000-video decoding workload. OS choosers are substituted. Disk-full is injected; crash recovery exits a separate real process. No multi-hour soak, physical drive removal, speaker/HDR measurement or Mac verification.'
}
foreach ($group in @('UiScenarios','Stress','NativeStress','Privacy')) {
    if (@($report[$group] | Where-Object { -not $_.passed }).Count -gt 0) { throw "Failed scenario in $group" }
}
foreach ($group in @('Load10000','Catalog50000')) {
    if (-not $report[$group].passed) { throw "Failed benchmark in $group" }
}
$profileLog = Join-Path $folder 'native-profile.log'
$uiProfileLog = Join-Path $folder 'native-ui-profile.log'
$report.ProfileTestRuns = 0
if ($report.ProfileStress.Count -eq 3 -and $report.ProfileUi.phases.Count -eq 4 -and
    @($report.ProfileStress | Where-Object { -not $_.passed }).Count -eq 0 -and
    (Test-Path -LiteralPath $profileLog) -and (Test-Path -LiteralPath $uiProfileLog) -and
    (Get-Content -Raw -Encoding UTF8 $profileLog).Contains('All tests passed.') -and
    (Get-Content -Raw -Encoding UTF8 $uiProfileLog).Contains('All tests passed.')) {
    $report.ProfileTestRuns = 4
}
if ($report.ProfileTestRuns -ne 4) { throw 'Missing or failing required profile checks' }
if ($report.Shutdown.Count -ne 18 -or @($report.Shutdown | Where-Object {
    $_.exitCode -ne 0 -or $_.timeout -or -not $_.withinCloseBudget -or -not $_.positionPreserved
}).Count -ne 0) { throw 'Missing or failing shutdown probes' }
$helperLog = Get-Content -LiteralPath (Join-Path $folder 'update-helper.log') -Raw -Encoding UTF8
foreach ($scenario in @('install','rollback','invalid-signature','corrupt-package','unsafe-archive')) {
    if (-not $helperLog.Contains("${scenario}: PASS")) { throw "Missing updater result: $scenario" }
}
$report.Updater = '5 isolated cases passed: install, startup rollback, invalid signature, corrupt package, unsafe archive'
$json = $report | ConvertTo-Json -Depth 12
[IO.File]::WriteAllText((Join-Path $folder 'test-report.json'), $json, [Text.UTF8Encoding]::new($false))
$rows = ($runs | ForEach-Object { "<tr><td>$($_.Suite)</td><td>$($_.Tests)</td><td>PASS</td><td><a href='$($_.Log)'>log</a></td></tr>" }) -join "`n"
$performanceRows = if ($report.Baseline1000 -and $report.Optimized1000) { @('coldScanMs','warmScanMs','batch1000Ms') | ForEach-Object {
    $before = $report.Baseline1000.$_
    $after = $report.Optimized1000.$_
    $factor = [math]::Round($before / $after, 1)
    "<tr><td>$_</td><td>$before ms</td><td>$after ms</td><td>$factor x</td></tr>"
} } else { '<tr><td colspan="4">Historical baseline not available on this machine.</td></tr>' }
$scenarioRows = @('UiScenarios','Stress','NativeStress','Privacy') | ForEach-Object {
    foreach ($item in $report[$_]) {
        $name = [System.Net.WebUtility]::HtmlEncode($item.name)
        "<tr><td>$name</td><td>$($item.ms) ms</td><td>PASS</td></tr>"
    }
}
$encoded = [System.Net.WebUtility]::HtmlEncode($json)
$resourceRows = @($report.Resources | ForEach-Object {
    $run = $_
    $mode = if ($run.Label -like 'profile*') { '\\Profile\\' } elseif ($run.Label -like 'debug*') { '\\Debug\\' } else { '\\package\\' }
    foreach ($app in @($run.Applications | Where-Object Path -Match $mode)) {
        "<tr><td>$($run.Label)</td><td>$($app.CpuAveragePercent)% / $($app.CpuPeakPercent)%</td><td>$($app.GpuPeakEnginePercent)%</td><td>$($app.PrivateWorkingPeakMiB) MiB</td><td>$($app.GpuSharedPeakMiB) MiB</td></tr>"
    }
})
$frameRows = @($report.ProfileUi.phases | ForEach-Object {
    "<tr><td>$($_.phase)</td><td>$($_.buildP95Ms) ms</td><td>$($_.rasterP95Ms) ms</td><td>$($_.overBudgetFrames) / $($_.frames)</td></tr>"
})
$html = @"
<!doctype html><html lang='en'><meta charset='utf-8'><title>Soft Vault verification</title>
<style>body{font:16px system-ui;max-width:1100px;margin:40px auto;background:#17222d;color:#d5e1ea}table{border-collapse:collapse;width:100%}td,th{padding:10px;border-bottom:1px solid #3b5366;text-align:left}a{color:#87b8d8}pre{white-space:pre-wrap;background:#203242;padding:20px;border-radius:8px}p{line-height:1.6}</style>
<h1>Soft Vault Windows verification</h1><p>$($report.TestCount) passing test-runner entries (native totals can include tearDownAll). Generated $($report.Generated)</p>
<p>18 native process shutdown probes and 5 isolated updater cases passed.</p>
<p>$($report.ProfileTestRuns) optimized profile checks also passed: the three stress workloads repeated in profile mode, plus normal four-video UI navigation, dialogs and playback.</p>
<table><tr><th>Suite</th><th>Test cases</th><th>Result</th><th>Evidence</th></tr>$rows</table>
<h2>Same 1000-file workload, before and after</h2><table><tr><th>Operation</th><th>Before</th><th>After</th><th>Speedup</th></tr>$($performanceRows -join "`n")</table>
<h2>Additional scenarios</h2><table><tr><th>Scenario</th><th>Duration</th><th>Result</th></tr>$($scenarioRows -join "`n")</table>
<h2>CPU, memory and GPU samples</h2><p>30-second Windows counter samples. CPU percentages cover all logical processors. GPU is the busiest engine. Workloads differ between idle and active runs. GPU shared memory is not additional dedicated VRAM.</p><table><tr><th>Run</th><th>App CPU average / peak</th><th>App GPU peak</th><th>App private working memory peak</th><th>GPU shared memory peak</th></tr>$($resourceRows -join "`n")</table>
<h2>Normal four-video UI in profile mode</h2><p>Frame policy: $($report.ProfileUi.framePolicy). Build and raster times are P95, not average FPS. Counts include transitions and warm-up frames. OS IME input is outside these tests.</p><table><tr><th>Action</th><th>Build P95</th><th>Raster P95</th><th>Over-budget frames / samples</th></tr>$($frameRows -join "`n")</table>
<p>$($report.Limits)</p><details open><summary>Scenario and performance measurements</summary><pre>$encoded</pre></details>
<a href='../e2e/review.html'>Design comparison</a> | <a href='../e2e/installed-results.json'>Installed package verification</a> | <a href='bottleneck-report.html'>Windows UI bottleneck investigation</a></html>
"@
[IO.File]::WriteAllText((Join-Path $folder 'test-report.html'), $html, [Text.UTF8Encoding]::new($false))
Write-Output "Passed: $($report.TestCount) tests. Report: build/verification/test-report.html"
