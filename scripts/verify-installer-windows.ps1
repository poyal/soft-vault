param([Parameter(Mandatory=$true)][string]$SetupExe, [Parameter(Mandatory=$true)][string]$VideoFixture)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
Set-Location $repo
$setup=(Resolve-Path -LiteralPath $SetupExe).Path
$fixture=(Resolve-Path -LiteralPath $VideoFixture).Path
$key='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\SoftVault_is1'
if(Test-Path $key){throw 'A registered user installation exists; use a separate test account'}
$id=[guid]::NewGuid().ToString('N')
$root=Join-Path $repo "build/installer-smoke/$id"
$target=Join-Path $root 'SoftVault'
$group='Soft Vault'
$shortcut=Join-Path ([Environment]::GetFolderPath('Programs')) "$group/Soft Vault.lnk"
if(Test-Path -LiteralPath $shortcut){throw 'Test shortcut already exists'}
New-Item -ItemType Directory -Force -Path $target | Out-Null
$sentinel=Join-Path $target 'retained-user-data.txt'
'preserve catalog data outside bin' | Set-Content -LiteralPath $sentinel
$originalHash=(Get-FileHash -LiteralPath $fixture).Hash
function Run-Checked([string]$Exe,[string[]]$Arguments) {
 $p=Start-Process -FilePath $Exe -ArgumentList $Arguments -WindowStyle Hidden -PassThru
 if(-not $p.WaitForExit(180000)){$p.Kill();throw "Process timed out: $Exe"}
 if($p.ExitCode -ne 0){throw "Process failed: $Exe ($($p.ExitCode))"}
}
$uninstaller=Join-Path $target 'uninstall/unins000.exe'
$savedPath=$env:PATH
$sqlite=Join-Path $repo 'build/native_assets/windows/sqlite3.dll'
$held=$sqlite+'.installer-check-hold'
$isolated=$false
try {
 for($run=1;$run -le 2;$run++) {
  Run-Checked $setup @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-',"/DIR=`"$target`"",'/TASKS=',"/LOG=`"$root/install-$run.log`"")
  $registration=Get-ItemProperty $key
  if($registration.InstallLocation.TrimEnd('\') -ne $target){throw 'Unexpected installer registration'}
  if(-not (Test-Path -LiteralPath $uninstaller)){throw 'Uninstaller must live outside updated bin'}
  $link=(New-Object -ComObject WScript.Shell).CreateShortcut($shortcut)
  if($link.TargetPath -ne [IO.Path]::GetFullPath((Join-Path $target 'bin/soft_vault.exe'))){throw 'Start Menu shortcut is incorrect'}
 }
 $manifest=Get-Content -Raw -Encoding utf8 build/package/SoftVault-Windows/manifest.json | ConvertFrom-Json
 $appFiles=@($manifest | Where-Object {$_.Path.Replace('\','/').StartsWith('app/')})
 foreach($entry in $appFiles){
  $relative=$entry.Path.Replace('\','/').Substring(4)
  if((Get-FileHash -LiteralPath (Join-Path "$target/bin" $relative)).Hash -ne $entry.SHA256){throw "Installed file mismatch: $relative"}
 }
 if(Test-Path -LiteralPath $sqlite){
  if(Test-Path -LiteralPath $held){throw 'Earlier SQLite isolation needs restoration'}
  Move-Item -LiteralPath $sqlite -Destination $held
  $isolated=$true
 }
 $env:PATH="$env:SystemRoot\System32;$env:SystemRoot"
 $report=Join-Path $root 'installed-results.json'
 Run-Checked (Join-Path $target 'bin/soft_vault.exe') @('--verify-install',"`"$report`"","`"$fixture`"","`"$repo/.tools/fixtures/codecs`"")
 $result=Get-Content -Raw -Encoding utf8 $report | ConvertFrom-Json
 if(-not $result.passed){throw 'Installed EXE diagnostic failed'}
 $env:PATH=$savedPath
 # Future updater-added files must also be removed, without touching user data.
 'future application component' | Set-Content -LiteralPath (Join-Path $target 'bin/future-component.test')
 Run-Checked $uninstaller @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',"/LOG=`"$root/uninstall.log`"")
 if((Test-Path $key) -or (Test-Path -LiteralPath $shortcut) -or (Test-Path -LiteralPath "$target/bin")){throw 'Uninstall left application registration or files'}
 if((Get-Content -LiteralPath $sentinel) -ne 'preserve catalog data outside bin'){throw 'User data was removed'}
 if((Get-FileHash -LiteralPath $fixture).Hash -ne $originalHash){throw 'Original fixture changed'}
 $result | Add-Member -NotePropertyName installerSHA256 -NotePropertyValue (Get-FileHash -LiteralPath $setup).Hash
 $result | Add-Member -NotePropertyName installation -NotePropertyValue @{fresh=$true;reinstall=$true;startMenu=$true;registeredUninstall=$true;uninstall=$true;retainedUserData=$true;verifiedAppFiles=$appFiles.Count;uninstallerOutsideBin=$true}
 New-Item -ItemType Directory -Force build/installer-020 | Out-Null
 $result | ConvertTo-Json -Depth 10 | Set-Content -Encoding utf8 build/installer-020/windows-installer-results.json
 'Installer, reinstall, shortcut, playback, uninstall and data preservation PASS'
} finally {
 $env:PATH=$savedPath
 if($isolated){Move-Item -LiteralPath $held -Destination $sqlite}
 # The executable can remain briefly while Inno's self-removal finishes.
 # Only retry cleanup when our own installation is still registered.
 if((Test-Path $key) -and (Test-Path -LiteralPath $uninstaller)){
  $remaining=Get-ItemProperty $key
  if($remaining.InstallLocation.TrimEnd('\') -eq $target){Run-Checked $uninstaller @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART')}
 }
}
