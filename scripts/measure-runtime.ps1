param([string]$Label = 'runtime', [int]$Seconds = 30)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$logical = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
$samples = [Collections.Generic.List[object]]::new()
$timer = [Diagnostics.Stopwatch]::StartNew()
while ($timer.Elapsed.TotalSeconds -lt $Seconds) {
    $iteration = [Diagnostics.Stopwatch]::StartNew()
    $cpu = Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'"
    $os = Get-CimInstance Win32_OperatingSystem
    $engines = @(Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine)
    $gpuMemory = @(Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUProcessMemory)
    $engineTotals = @($engines | Group-Object { $_.Name -replace '^pid_\d+_', '' } | ForEach-Object {
        ($_.Group | Measure-Object UtilizationPercentage -Sum).Sum
    })
    $processes = @(Get-CimInstance Win32_PerfFormattedData_PerfProc_Process |
        Where-Object { $_.IDProcess -gt 0 -and $_.Name -ne '_Total' })
    $rows = @($processes | Where-Object { $_.PercentProcessorTime -gt 0 -or $_.Name -match 'soft_vault|dart|ffmpeg|MSBuild' } | ForEach-Object {
        $processId = $_.IDProcess
        $pattern = "^pid_$($processId)_"
        $gpu = @($engines | Where-Object Name -Match $pattern)
        $memory = @($gpuMemory | Where-Object Name -Match $pattern)
        $path = $null
        if ($_.Name -match '^soft_vault') {
            $path = (Get-Process -Id $processId -ErrorAction SilentlyContinue).Path
        }
        [pscustomobject]@{
            Name = $_.Name; Pid = $processId; Path = $path
            CpuPercent = [math]::Round($_.PercentProcessorTime / $logical, 2)
            PrivateWorkingMiB = [math]::Round($_.WorkingSetPrivate / 1MB, 1)
            GpuPeakEnginePercent = ($gpu | Measure-Object UtilizationPercentage -Maximum).Maximum
            GpuSharedMiB = [math]::Round(($memory | Measure-Object SharedUsage -Sum).Sum / 1MB, 1)
            GpuDedicatedMiB = [math]::Round(($memory | Measure-Object DedicatedUsage -Sum).Sum / 1MB, 1)
        }
    })
    $samples.Add([pscustomobject]@{
        At = [DateTime]::Now.ToString('o'); CpuPercent = $cpu.PercentProcessorTime
        AvailableGiB = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
        GpuBusiestEnginePercent = ($engineTotals | Measure-Object -Maximum).Maximum
        Processes = $rows
    })
    $remaining = 2000 - $iteration.ElapsedMilliseconds
    if ($remaining -gt 0) { Start-Sleep -Milliseconds $remaining }
}
$appRows = @($samples | ForEach-Object { $_.Processes } | Where-Object Name -Match '^soft_vault')
$summary = [ordered]@{
    Label = $Label; DurationSeconds = [math]::Round($timer.Elapsed.TotalSeconds, 1); Samples = $samples.Count
    CpuAveragePercent = [math]::Round(($samples | Measure-Object CpuPercent -Average).Average, 1)
    CpuPeakPercent = ($samples | Measure-Object CpuPercent -Maximum).Maximum
    GpuAverageBusiestEnginePercent = [math]::Round(($samples | Measure-Object GpuBusiestEnginePercent -Average).Average, 1)
    GpuPeakBusiestEnginePercent = ($samples | Measure-Object GpuBusiestEnginePercent -Maximum).Maximum
    MinimumAvailableGiB = ($samples | Measure-Object AvailableGiB -Minimum).Minimum
    Applications = @($appRows | Group-Object Pid | ForEach-Object {
        [pscustomobject]@{
            Pid = $_.Name; Path = $_.Group[0].Path; Samples = $_.Count
            CpuAveragePercent = [math]::Round(($_.Group | Measure-Object CpuPercent -Average).Average, 2)
            CpuPeakPercent = ($_.Group | Measure-Object CpuPercent -Maximum).Maximum
            PrivateWorkingPeakMiB = ($_.Group | Measure-Object PrivateWorkingMiB -Maximum).Maximum
            GpuPeakEnginePercent = ($_.Group | Measure-Object GpuPeakEnginePercent -Maximum).Maximum
            GpuSharedPeakMiB = ($_.Group | Measure-Object GpuSharedMiB -Maximum).Maximum
        }
    })
    Note = 'CPU is normalized across all logical processors. GPU percentages use the busiest engine, not the sum of different engines. Windows formatted counters are sampled approximately every 2 seconds. Private working memory excludes shared pages.'
}
$report = [ordered]@{ Summary = $summary; Samples = @($samples.ToArray()) }
$output = Join-Path $repoRoot "build/verification/resources-$Label.json"
[IO.File]::WriteAllText($output, ($report | ConvertTo-Json -Depth 9), [Text.UTF8Encoding]::new($false))
$summary | ConvertTo-Json -Depth 5
