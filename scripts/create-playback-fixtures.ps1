param([int]$Seconds = 310, [string]$OutputDirectory = '')
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $repo '.tools/playback-fixtures' }
$ffmpeg = Join-Path $repo '.tools/ffmpeg/extracted/ffmpeg-9.0.2-essentials_build/bin/ffmpeg.exe'
$ffprobe = Join-Path (Split-Path $ffmpeg -Parent) 'ffprobe.exe'
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$cases = @(
    @{ Name = 'h264-1080p24-long-gop.mp4'; Size = '1920x1080'; Rate = 24; Codec = 'h264_nvenc'; Pixel = 'yuv420p' },
    @{ Name = 'h264-1080p30.mp4'; Size = '1920x1080'; Rate = 30; Codec = 'h264_nvenc'; Pixel = 'yuv420p' },
    @{ Name = 'h264-1080p60.mp4'; Size = '1920x1080'; Rate = 60; Codec = 'h264_nvenc'; Pixel = 'yuv420p' },
    @{ Name = 'hevc-4k24-10bit.mkv'; Size = '3840x2160'; Rate = 24; Codec = 'hevc_nvenc'; Pixel = 'p010le' },
    @{ Name = 'hevc-4k60-10bit.mkv'; Size = '3840x2160'; Rate = 60; Codec = 'hevc_nvenc'; Pixel = 'p010le' }
)
$records = @()
foreach ($case in $cases) {
    $target = Join-Path $OutputDirectory $case.Name
    if (-not (Test-Path -LiteralPath $target)) {
        Write-Output "Generating $($case.Name)"
        $gop = if ($case.Name -like '*long-gop*') { $case.Rate * 10 } else { $case.Rate * 2 }
        & $ffmpeg -nostdin -hide_banner -loglevel error -f lavfi -i "testsrc2=size=$($case.Size):rate=$($case.Rate)" -f lavfi -i 'sine=frequency=440:sample_rate=48000' -t $Seconds -c:v $case.Codec -preset p4 -cq 23 -g $gop -bf 3 -pix_fmt $case.Pixel -c:a aac -b:a 128k $target
        if ($LASTEXITCODE -ne 0) { throw "Encoding failed: $($case.Name)" }
    }
    $probe = (& $ffprobe -v error -show_format -show_streams -of json $target | Out-String | ConvertFrom-Json)
    if ($LASTEXITCODE -ne 0 -or [double]$probe.format.duration -lt $Seconds - 1) { throw "Incomplete fixture: $target" }
    $records += @{ file = $case.Name; sha256 = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant(); probe = $probe }
}
$vfr = Join-Path $OutputDirectory 'h264-1080p-vfr.mkv'
if (-not (Test-Path -LiteralPath $vfr)) {
    & $ffmpeg -nostdin -hide_banner -loglevel error -i (Join-Path $OutputDirectory 'h264-1080p30.mp4') -vf "select='if(lt(mod(t,10),5),not(mod(n,2)),1)'" -fps_mode vfr -c:v h264_nvenc -preset p4 -cq 23 -g 60 -c:a copy $vfr
    if ($LASTEXITCODE -ne 0) { throw 'VFR encoding failed' }
}
$records += @{ file = (Split-Path $vfr -Leaf); sha256 = (Get-FileHash -LiteralPath $vfr -Algorithm SHA256).Hash.ToLowerInvariant(); probe = (& $ffprobe -v error -show_format -show_streams -of json $vfr | Out-String | ConvertFrom-Json) }
$manifest = @{ generatedAt = [DateTime]::UtcNow.ToString('o'); kind = 'synthetic moving test pattern with AAC tone; not real-world content'; durationSeconds = $Seconds; ffmpegVersion = (& $ffmpeg -version)[0]; ffprobeVersion = (& $ffprobe -version)[0]; files = $records } | ConvertTo-Json -Depth 30
[IO.File]::WriteAllText((Join-Path $OutputDirectory 'manifest.json'), $manifest, [Text.UTF8Encoding]::new($false))
Write-Output "Fixtures ready: $OutputDirectory"
