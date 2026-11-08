function Invoke-FlutterCheck([string]$Label, [string[]]$Arguments) {
    $repo = Split-Path -Parent $PSScriptRoot
    $flutterCommand = Join-Path $repo '.tools/flutter/bin/flutter.bat'
    if (-not (Test-Path -LiteralPath $flutterCommand)) {
        $flutterCommand = (Get-Command flutter -ErrorAction Stop).Source
    }
    $savedTemp = $env:TEMP
    $savedTmp = $env:TMP
    $previousErrorAction = $ErrorActionPreference
    try {
        if (@($Arguments | Where-Object { $_ -match '(^|=)integration_test/' }).Count -gt 0) {
            # media_kit's debug hot-restart cache stores native pointers by PID.
            # Windows can reuse a PID after an earlier test exits. Give each
            # process run its own temp directory so stale pointers cannot recur.
            $testTemp = Join-Path $repo ('build/verification/runtime-temp/' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $testTemp -Force | Out-Null
            $env:TEMP = $testTemp
            $env:TMP = $testTemp
        }
        $ErrorActionPreference = 'Continue'
        & $flutterCommand @Arguments *> (Join-Path $repo "build/verification/$Label.log")
        $code = $LASTEXITCODE
        if ($code -ne 0) {
            Get-Content -Encoding UTF8 (Join-Path $repo "build/verification/$Label.log") -Tail 70
            throw "$Label failed with exit code $code"
        }
        Write-Output "Passed $Label"
    } finally {
        $env:TEMP = $savedTemp
        $env:TMP = $savedTmp
        $ErrorActionPreference = $previousErrorAction
    }
}
