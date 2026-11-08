$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$release = Join-Path $repoRoot 'build/windows/x64/runner/Release'
if (-not (Test-Path (Join-Path $release 'soft_vault.exe'))) { throw 'Build Windows release first.' }
foreach ($required in @('tools/ffmpeg.exe','tools/ffprobe.exe','libmpv-2.dll','flutter_windows.dll','data/app.so')) {
  if (-not (Test-Path (Join-Path $release $required))) { throw "Missing bundled runtime: $required" }
}
$package = Join-Path $repoRoot 'build/package/SoftVault-Windows'
New-Item -ItemType Directory -Force -Path (Join-Path $package 'app') | Out-Null
Copy-Item -Path (Join-Path $release '*') -Destination (Join-Path $package 'app') -Recurse -Force
# The root manifest is a development-side file with an absolute workspace path.
# Flutter's release manifest under data/flutter_assets resolves bundled sqlite3.dll.
$developmentManifest = Join-Path $package 'app/native_assets.json'
if (Test-Path -LiteralPath $developmentManifest) { Remove-Item -LiteralPath $developmentManifest -Force }
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$vsPath = & $vswhere -latest -products '*' -property installationPath
$runtimeVersion = Get-ChildItem -LiteralPath (Join-Path $vsPath 'VC/Redist/MSVC') -Directory | Where-Object Name -Match '^\d' | Sort-Object Name -Descending | Select-Object -First 1
if (-not $runtimeVersion) { throw 'Visual C++ redistributable runtime not found.' }
$runtime = Join-Path $runtimeVersion.FullName 'x64/Microsoft.VC143.CRT'
Copy-Item -Path (Join-Path $runtime '*.dll') -Destination (Join-Path $package 'app') -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'install-windows.ps1') -Destination (Join-Path $package 'Install.ps1') -Force
Copy-Item -LiteralPath (Join-Path $repoRoot 'THIRD_PARTY_NOTICES.txt') -Destination $package -Force
[System.IO.File]::WriteAllText((Join-Path $package 'README.txt'), @'
Soft Vault for Windows x64

Portable: open app\soft_vault.exe. Keep the complete app folder together.
Install: run Install.ps1 with PowerShell. It copies the complete app to
%LOCALAPPDATA%\SoftVault\bin and creates a Start Menu shortcut.
No administrator rights, Flutter SDK, FFmpeg installation or codec pack is needed.
Library metadata is stored separately in the Windows application data directory.
Closing or replacing this app folder does not remove source media or the catalog.
Set an app-start password on first launch or in Settings > Privacy.
Changing or disabling an existing password requires the current password.
This locks app access; source videos and catalog files are not encrypted.
There is no in-app password recovery. Catalog backups do not include the lock.

The bundled components and their licenses are listed in THIRD_PARTY_NOTICES.txt.
'@, [System.Text.UTF8Encoding]::new($false))
$manifest = Get-ChildItem -LiteralPath $package -Recurse -File | Where-Object Name -ne 'manifest.json' | ForEach-Object {
  [PSCustomObject]@{ Path=$_.FullName.Substring($package.Length+1); SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $package 'manifest.json') -Encoding UTF8
Compress-Archive -Path $package -DestinationPath (Join-Path $repoRoot 'build/package/SoftVault-Windows.zip') -Force
$zip = Join-Path $repoRoot 'build/package/SoftVault-Windows.zip'
((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash + '  SoftVault-Windows.zip') | Set-Content -LiteralPath ($zip + '.sha256') -Encoding ASCII
Get-Item -LiteralPath (Join-Path $repoRoot 'build/package/SoftVault-Windows.zip') | Select-Object FullName,Length
