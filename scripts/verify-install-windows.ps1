param([Parameter(Mandatory = $true)][string]$VideoFixture)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$fixture = (Resolve-Path -LiteralPath $VideoFixture).Path
$smokeRoot = Join-Path $repoRoot ('build/install-smoke/' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $smokeRoot | Out-Null
Expand-Archive -LiteralPath (Join-Path $repoRoot 'build/package/SoftVault-Windows.zip') -DestinationPath $smokeRoot
$packageRoot = Join-Path $smokeRoot 'SoftVault-Windows'
$manifest = Get-Content -LiteralPath (Join-Path $packageRoot 'manifest.json') -Raw | ConvertFrom-Json
foreach ($entry in $manifest) {
  $file = Join-Path $packageRoot $entry.Path
  if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $entry.SHA256) { throw "Package checksum mismatch: $($entry.Path)" }
}
$installed = Join-Path $smokeRoot 'installed/bin'
& (Join-Path $packageRoot 'Install.ps1') -Destination $installed -NoShortcut
$report = Join-Path $smokeRoot 'installed-results.json'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $report) | Out-Null
$launchArgs = @('--verify-install', ('"' + $report + '"'), ('"' + $fixture + '"'), ('"' + (Join-Path $repoRoot '.tools/fixtures/codecs') + '"'))
$savedPath = $env:PATH
$developmentSqlite = Join-Path $repoRoot 'build/native_assets/windows/sqlite3.dll'
$heldSqlite = $developmentSqlite + '.install-check-hold'
$isolatedSqlite = $false
try {
  if (Test-Path -LiteralPath $developmentSqlite) {
    if (Test-Path -LiteralPath $heldSqlite) { throw 'An earlier SQLite isolation check needs restoration.' }
    Move-Item -LiteralPath $developmentSqlite -Destination $heldSqlite
    $isolatedSqlite = $true
  }
  # Resolve only Windows system DLLs and the app's bundled dependencies.
  $env:PATH = "$env:SystemRoot\System32;$env:SystemRoot"
  $process = Start-Process -FilePath (Join-Path $installed 'soft_vault.exe') -ArgumentList $launchArgs -WorkingDirectory $installed -WindowStyle Hidden -PassThru
  if (-not $process.WaitForExit(120000)) {
    $process.Kill()
    throw 'Installed application verification timed out.'
  }
  if ($process.ExitCode -ne 0) {
    if (Test-Path -LiteralPath $report) { Get-Content -LiteralPath $report }
    throw "Installed application failed: $($process.ExitCode)"
  }
  $result = Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
  if (-not $result.passed) { throw 'Installed application reported a failed check.' }
  if ([IO.Path]::GetFullPath($result.executable) -ne [IO.Path]::GetFullPath((Join-Path $installed 'soft_vault.exe'))) {
    throw 'Installed report does not belong to this isolated installation.'
  }
  $result | Add-Member -NotePropertyName 'packageHashesVerified' -NotePropertyValue $manifest.Count
  $result | Add-Member -NotePropertyName 'pathContainsDevelopmentTools' -NotePropertyValue $false
  $result | Add-Member -NotePropertyName 'developmentSqliteUnavailable' -NotePropertyValue $true
  $result | Add-Member -NotePropertyName 'packageSHA256' -NotePropertyValue (Get-FileHash -LiteralPath (Join-Path $repoRoot 'build/package/SoftVault-Windows.zip') -Algorithm SHA256).Hash
  $result | Add-Member -NotePropertyName 'verifiedAtUTC' -NotePropertyValue ([DateTime]::UtcNow.ToString('o'))
  $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $report -Encoding UTF8
  Copy-Item -LiteralPath $report -Destination (Join-Path $repoRoot 'build/e2e/installed-results.json') -Force
  Get-Content -LiteralPath $report
} finally {
  $env:PATH = $savedPath
  if ($isolatedSqlite) { Move-Item -LiteralPath $heldSqlite -Destination $developmentSqlite }
}
