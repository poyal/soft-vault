param(
    [Parameter(Mandatory=$true)][string]$Player,
    [Parameter(Mandatory=$true)][string]$FixtureDirectory,
    [Parameter(Mandatory=$true)][string]$Output,
    [int]$Seconds = 10,
    [int]$Seeks = 30
)
# PowerShell 7: await the actual GUI executable, not a shell launch acknowledgement.
$ErrorActionPreference = 'Stop'
$executable = (Resolve-Path -LiteralPath $Player).Path
$fixture = (Resolve-Path -LiteralPath $FixtureDirectory).Path
$resultPath = [IO.Path]::GetFullPath($Output)
if (Test-Path -LiteralPath $resultPath) { throw 'Use a new output path.' }
if (Get-Process -Name mpv -ErrorAction SilentlyContinue | Where-Object Path -EQ $executable) { throw 'This reference player is already running.' }
$files = @(Get-ChildItem -LiteralPath $fixture -File | Where-Object Extension -In '.mp4','.mkv' | Sort-Object Name)
if ($files.Count -eq 0) { throw 'No video fixtures.' }
New-Item -ItemType Directory -Path (Split-Path -Parent $resultPath) -Force | Out-Null
$start = [Diagnostics.ProcessStartInfo]::new($executable)
$start.UseShellExecute = $false
$start.CreateNoWindow = $true
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
foreach ($argument in @('--no-config','--hwdec=auto','--volume=0','--force-window=yes','--geometry=1280x800','--msg-level=all=warn',"--script=$PSScriptRoot/playback-reference.lua","--script-opts=quality-output=$resultPath,quality-seconds=$Seconds,quality-seeks=$Seeks")) { $start.ArgumentList.Add($argument) }
foreach ($file in $files) { $start.ArgumentList.Add($file.FullName) }
$started = [DateTime]::UtcNow
$process = [Diagnostics.Process]::Start($start)
$outputTask = $process.StandardOutput.ReadToEndAsync()
$errorTask = $process.StandardError.ReadToEndAsync()
if (-not $process.WaitForExit(600000)) {
    $process.Kill()
    throw 'mpv reference timed out.'
}
[IO.File]::WriteAllText($resultPath + '.log', $outputTask.GetAwaiter().GetResult() + $errorTask.GetAwaiter().GetResult(), [Text.UTF8Encoding]::new($false))
if ($process.ExitCode -ne 0) { throw "mpv exited with $($process.ExitCode)" }
$report = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
if ($report.files.Count -ne $files.Count -or @($report.files | Where-Object { -not $_.completed -or $_.error }).Count -gt 0) { throw 'mpv reference did not complete every file.' }
$report | Add-Member -NotePropertyName run -NotePropertyValue @{executable=$executable; startedAtUTC=$started.ToString('o'); finishedAtUTC=[DateTime]::UtcNow.ToString('o'); processExitCode=$process.ExitCode}
[IO.File]::WriteAllText($resultPath, ($report | ConvertTo-Json -Depth 40), [Text.UTF8Encoding]::new($false))
Write-Output 'mpv reference completed and process exited'
