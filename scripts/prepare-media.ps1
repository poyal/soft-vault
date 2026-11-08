$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$destination = Join-Path $repoRoot '.tools/ffmpeg'
New-Item -ItemType Directory -Force -Path $destination | Out-Null
$archive = Join-Path $destination 'archive.zip'
$expected = '60F467265B1E312373DBCD92200C2618A74850F98D3D078E94296BB3FA2047BA'
if (-not (Test-Path -LiteralPath $archive)) {
  Invoke-WebRequest 'https://github.com/GyanD/codexffmpeg/releases/download/9.0.2/ffmpeg-9.0.2-essentials_build.zip' -OutFile $archive
}
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $expected) { throw 'FFmpeg archive checksum mismatch.' }
Expand-Archive -LiteralPath $archive -DestinationPath (Join-Path $destination 'extracted') -Force
