$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$ffmpeg = Join-Path $repoRoot '.tools/ffmpeg/extracted/ffmpeg-9.0.2-essentials_build/bin/ffmpeg.exe'
$fixtures = Join-Path $repoRoot '.tools/fixtures/codecs'
New-Item -ItemType Directory -Force -Path $fixtures | Out-Null
$cases = @(
  @{ Name='h264-aac.mp4'; Video='libx264'; Audio='aac'; Extra=@('-preset','ultrafast') },
  @{ Name='hevc10-eac3.mkv'; Video='libx265'; Audio='eac3'; Extra=@('-preset','ultrafast','-pix_fmt','yuv420p10le','-x265-params','log-level=error:pools=2') },
  @{ Name='av1-flac.mkv'; Video='libaom-av1'; Audio='flac'; Extra=@('-cpu-used','8','-crf','45') },
  @{ Name='vp9-opus.webm'; Video='libvpx-vp9'; Audio='libopus'; Extra=@('-deadline','realtime','-cpu-used','8') },
  @{ Name='mpeg4-mp3.avi'; Video='mpeg4'; Audio='libmp3lame'; Extra=@() },
  @{ Name='h264-pcm.mov'; Video='libx264'; Audio='pcm_s16le'; Extra=@('-preset','ultrafast') },
  @{ Name='h264-ac3.ts'; Video='libx264'; Audio='ac3'; Extra=@('-preset','ultrafast') },
  @{ Name='h264-dts.mkv'; Video='libx264'; Audio='dca'; Extra=@('-preset','ultrafast','-strict','-2') }
)
foreach ($case in $cases) {
  $target = Join-Path $fixtures $case.Name
  $arguments = @('-nostdin','-hide_banner','-loglevel','error','-y','-f','lavfi','-i','testsrc2=size=320x180:rate=24','-f','lavfi','-i','sine=frequency=440:sample_rate=48000','-t','2','-c:v',$case.Video,'-c:a',$case.Audio,'-threads','2') + $case.Extra + @($target)
  & $ffmpeg @arguments
  if ($LASTEXITCODE -ne 0) { throw "Fixture failed: $($case.Name)" }
}
& $ffmpeg -nostdin -hide_banner -loglevel error -y -f lavfi -i 'testsrc2=size=3840x2160:rate=24' -t 1 -c:v libx265 -preset ultrafast -pix_fmt yuv420p10le -color_primaries bt2020 -color_trc smpte2084 -colorspace bt2020nc -x265-params 'log-level=error:pools=2:colorprim=9:transfer=16:colormatrix=9:hdr10=1:hdr10-opt=1:master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L(10000000,1):max-cll=1000,400' (Join-Path $fixtures 'hevc4k-hdr.mkv')
if ($LASTEXITCODE -ne 0) { throw '4K fixture failed' }
$vc1 = Join-Path $repoRoot '.tools/fixtures/vc1-source.wmv'
if (-not (Test-Path -LiteralPath $vc1)) { Invoke-WebRequest 'https://samples.ffmpeg.org/V-codecs/WVC1/Test_1440x576_WVC1_6Mbps.wmv' -OutFile $vc1 }
& $ffmpeg -nostdin -hide_banner -loglevel error -y -i $vc1 -t 2 -c copy (Join-Path $fixtures 'vc1.wmv')
if ($LASTEXITCODE -ne 0) { throw 'VC-1 fixture failed' }
$srt = "1`n00:00:00,000 --> 00:00:01,800`nSoft Vault subtitle test`n"
[System.IO.File]::WriteAllText((Join-Path $fixtures 'sample.srt'), $srt, [System.Text.UTF8Encoding]::new($false))
$ass = "[Script Info]`nScriptType: v4.00+`n[V4+ Styles]`nFormat: Name, Fontname, Fontsize, PrimaryColour`nStyle: Default,Arial,24,&H00FFFFFF`n[Events]`nFormat: Layer, Start, End, Style, Text`nDialogue: 0,0:00:00.00,0:00:01.80,Default,ASS subtitle test`n"
[System.IO.File]::WriteAllText((Join-Path $fixtures 'sample.ass'), $ass, [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText((Join-Path $fixtures 'sample.smi'), '<SAMI><BODY><SYNC Start=0><P Class=ENCC>SMI subtitle test<SYNC Start=1800><P Class=ENCC>&nbsp;</BODY></SAMI>', [System.Text.UTF8Encoding]::new($false))
& $ffmpeg -nostdin -hide_banner -loglevel error -y -i (Join-Path $fixtures 'h264-aac.mp4') -i (Join-Path $fixtures 'sample.srt') -map 0 -map 1 -c:v copy -c:a copy -c:s srt (Join-Path $fixtures 'embedded-subtitle.mkv')
if ($LASTEXITCODE -ne 0) { throw 'Embedded subtitle fixture failed' }
Get-ChildItem -LiteralPath $fixtures | Select-Object Name,Length
