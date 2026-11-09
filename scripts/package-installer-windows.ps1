param(
    [string]$PackageZip = 'build/package/SoftVault-Windows.zip',
    [string]$Compiler = '.tools/inno/ISCC.exe',
    [string]$OutputDirectory = 'build/package'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Push-Location $repo
try {
    $zip = (Resolve-Path -LiteralPath $PackageZip).Path
    $iscc = (Resolve-Path -LiteralPath $Compiler).Path
    $output = [IO.Path]::GetFullPath((Join-Path $repo $OutputDirectory))
    New-Item -ItemType Directory -Force -Path $output | Out-Null
    $stage = Join-Path $repo ('build/installer-stage/' + [guid]::NewGuid().ToString('N'))
    Expand-Archive -LiteralPath $zip -DestinationPath $stage
    $payload = Join-Path $stage 'SoftVault-Windows'
    $manifest = Get-Content -Raw -Encoding utf8 (Join-Path $payload 'manifest.json') | ConvertFrom-Json
    foreach ($entry in $manifest) {
        $path = [IO.Path]::GetFullPath((Join-Path $payload $entry.Path))
        if (-not $path.StartsWith($payload + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe manifest path' }
        if ((Get-FileHash -LiteralPath $path).Hash -ne $entry.SHA256) { throw "Invalid payload: $($entry.Path)" }
    }
    $config = Get-Content -Raw -Encoding utf8 (Join-Path $payload 'app/data/flutter_assets/assets/update-config.json') | ConvertFrom-Json
    $version = ($config.version -split '\+')[0]
    if ($version -notmatch '^\d+\.\d+\.\d+$') { throw 'Invalid package version' }
    & $iscc "/DPayload=$payload" "/DAppVersion=$version" "/O$output" (Join-Path $PSScriptRoot 'windows-installer.iss')
    if ($LASTEXITCODE -ne 0) { throw 'Installer compilation failed' }
    $exe = Join-Path $output "SoftVault-$version-Windows-x64-Setup.exe"
    ((Get-FileHash -LiteralPath $exe).Hash.ToLowerInvariant() + '  ' + [IO.Path]::GetFileName($exe)) | Set-Content -Encoding ascii ($exe + '.sha256')
    [ordered]@{ sourceZipSHA256=(Get-FileHash -LiteralPath $zip).Hash; installerSHA256=(Get-FileHash -LiteralPath $exe).Hash; payloadFiles=$manifest.Count; version=$config.version; uninstallerOutsideUpdatedBin=$true } | ConvertTo-Json | Set-Content -Encoding utf8 (Join-Path $output 'windows-installer-provenance.json')
    Get-Item -LiteralPath $exe | Select-Object Name,Length
} finally { Pop-Location }
