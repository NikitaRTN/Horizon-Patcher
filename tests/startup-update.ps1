$ErrorActionPreference = 'Stop'
$base = Join-Path ([IO.Path]::GetTempPath()) ('horizon-self-update-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $base | Out-Null
try {
    $source = Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot '..\src\finish-update.ps1')
    $source = $source.Replace("Start-Process -FilePath `$env:HP_DEST -ArgumentList '--updated' | Out-Null", "[IO.File]::WriteAllText(`$env:HP_MARKER,'started --updated')")
    $source = $source.Substring(0, $source.LastIndexOf('} catch {')) + "} catch { Write-Error `$_.Exception.Message; exit 1 }`n"
    $script = Join-Path $base 'helper.ps1'
    [IO.File]::WriteAllText($script,$source,[Text.UTF8Encoding]::new($true))
    $env:HP_DEST = Join-Path $base 'Patcher With Spaces.exe'
    $env:HP_TEMP = Join-Path $base 'update.exe'
    $env:HP_MARKER = Join-Path $base 'started.txt'
    function WriteFiles {
        [IO.File]::WriteAllText($env:HP_DEST,'old')
        [IO.File]::WriteAllText($env:HP_TEMP,'new')
        $env:HP_OLD_HASH=(Get-FileHash $env:HP_DEST -Algorithm SHA256).Hash
        $env:HP_NEW_HASH=(Get-FileHash $env:HP_TEMP -Algorithm SHA256).Hash
        Remove-Item $env:HP_MARKER -ErrorAction SilentlyContinue
    }
    function RunHelper([int]$parent) {
        $env:HP_PARENT=$parent
        $proc=Start-Process powershell.exe -ArgumentList @('-NoLogo','-NoProfile','-NonInteractive','-File',('"'+$script+'"')) -PassThru -RedirectStandardOutput (Join-Path $base 'out.txt') -RedirectStandardError (Join-Path $base 'err.txt')
        $null=$proc.Handle
        return $proc
    }
    WriteFiles
    $waiter=Start-Process powershell.exe -ArgumentList @('-NoProfile','-Command','Start-Sleep -Seconds 3') -PassThru
    $helper=RunHelper $waiter.Id
    Start-Sleep -Milliseconds 500
    if ([IO.File]::ReadAllText($env:HP_DEST) -ne 'old') { throw 'Replaced file before parent exited' }
    $helper.WaitForExit()
    if($helper.ExitCode -ne 0) { throw ('Helper failed: '+(Get-Content (Join-Path $base 'err.txt') -Raw)) }
    if([IO.File]::ReadAllText($env:HP_DEST) -ne 'new' -or -not (Test-Path $env:HP_MARKER) -or (Test-Path $env:HP_TEMP)) { throw 'Update or relaunch failed' }
    WriteFiles
    [IO.File]::WriteAllText($env:HP_DEST,'modified')
    $helper=RunHelper 2147483647; $helper.WaitForExit()
    if($helper.ExitCode -eq 0 -or [IO.File]::ReadAllText($env:HP_DEST) -ne 'modified' -or (Test-Path $env:HP_MARKER)) { throw 'Changed original was not protected' }
    WriteFiles
    [IO.File]::WriteAllText($env:HP_TEMP,'tampered')
    $helper=RunHelper 2147483647; $helper.WaitForExit()
    if($helper.ExitCode -eq 0 -or [IO.File]::ReadAllText($env:HP_DEST) -ne 'old' -or (Test-Path $env:HP_MARKER)) { throw 'Corrupt update was not rejected' }
    Write-Host 'PASS: waits for exit, replaces atomically, relaunches, protects changed files and rejects tampering'
} finally {
    Remove-Item Env:HP_DEST, Env:HP_TEMP, Env:HP_MARKER, Env:HP_OLD_HASH, Env:HP_NEW_HASH, Env:HP_PARENT -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
}
