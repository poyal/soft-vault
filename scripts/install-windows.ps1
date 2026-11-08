param([string]$Destination = (Join-Path $env:LOCALAPPDATA 'SoftVault/bin'), [switch]$NoShortcut)
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'app'
if (-not (Test-Path -LiteralPath (Join-Path $source 'soft_vault.exe'))) { throw 'Run Install.ps1 from the extracted SoftVault-Windows package.' }
$target = [System.IO.Path]::GetFullPath($Destination)
if ($target -eq [System.IO.Path]::GetPathRoot($target)) { throw 'Choose an application directory, not a drive root.' }
$active = Get-Process -Name soft_vault -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq (Join-Path $target 'soft_vault.exe') }
if ($active) { throw 'Close Soft Vault before installing this version.' }
New-Item -ItemType Directory -Force -Path $target | Out-Null
Copy-Item -Path (Join-Path $source '*') -Destination $target -Recurse -Force
if (-not $NoShortcut) {
  $programs = [Environment]::GetFolderPath('Programs')
  $shell = New-Object -ComObject WScript.Shell
  $shortcut = $shell.CreateShortcut((Join-Path $programs 'Soft Vault.lnk'))
  $shortcut.TargetPath = Join-Path $target 'soft_vault.exe'
  $shortcut.WorkingDirectory = $target
  $shortcut.IconLocation = Join-Path $target 'soft_vault.exe'
  $shortcut.Save()
}
Write-Output "Installed Soft Vault: $target"
