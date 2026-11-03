param([Parameter(Mandatory=$true)][string]$Patcher, [Parameter(Mandatory=$true)][string]$Official)
$ErrorActionPreference = 'Stop'
$oldHome = $env:LOCALAPPDATA
$base = Join-Path ([IO.Path]::GetTempPath()) ('horizon-scheduler-test-' + [guid]::NewGuid().ToString('N'))
$taskName = $null
try {
    New-Item -ItemType Directory -Force (Join-Path $base 'local'), (Join-Path $base 'install with spaces') | Out-Null
    $env:LOCALAPPDATA = Join-Path $base 'local'
    $target = Join-Path $base 'install with spaces\horizon-launcher.exe'
    Copy-Item -LiteralPath $Official -Destination $target
    function RunPatcher([string]$mode, [bool]$expectedFailure = $false) {
        $p = Start-Process -FilePath $Patcher -ArgumentList @($mode, ('"' + $target + '"')) -Wait -PassThru -RedirectStandardOutput (Join-Path $base 'stdout.txt') -RedirectStandardError (Join-Path $base 'stderr.txt')
        if ($p.ExitCode -ne 0 -and -not $expectedFailure) { Write-Host (Get-Content (Join-Path $base 'stderr.txt') -Raw) }
        return $p.ExitCode
    }
    if ((RunPatcher '--install') -ne 0) { throw 'Install fixture failed' }
    $stateDir = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'HorizonPrivacyPatcher') -Directory | Select-Object -First 1
    $taskName = 'HorizonPrivacyPatcher-' + $stateDir.Name
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) { throw 'Install created an unexpected task' }
    $legacy = Join-Path $stateDir.FullName 'updater.exe'
    Copy-Item -LiteralPath $Patcher -Destination $legacy
    $args = '--watch "' + $target + '"'
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddHours(1)
    $action = New-ScheduledTaskAction -Execute $legacy -Argument $args
    Register-ScheduledTask -TaskName $taskName -TaskPath '\' -Action $action -Trigger $trigger | Out-Null
    $locked = [IO.File]::Open($legacy, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try { if ((RunPatcher '--apply') -ne 0) { throw 'Old task removal failed' } } finally { $locked.Dispose() }
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) { throw 'Old task was not removed' }
    $action = New-ScheduledTaskAction -Execute 'notepad.exe' -Argument 'custom'
    Register-ScheduledTask -TaskName $taskName -TaskPath '\' -Action $action -Trigger $trigger | Out-Null
    if ((RunPatcher '--apply' $true) -eq 0) { throw 'Custom action was not rejected' }
    $custom = Get-ScheduledTask -TaskName $taskName -TaskPath '\'
    if ($custom.Actions[0].Execute -ne 'notepad.exe' -or $custom.Actions[0].Arguments -ne 'custom') { throw 'Custom task was removed or changed' }
    Write-Host 'PASS: install creates no task; old task removed even when updater is locked; custom task protected'
} finally {
    if ($taskName) { Unregister-ScheduledTask -TaskName $taskName -TaskPath '\' -Confirm:$false -ErrorAction SilentlyContinue }
    $env:LOCALAPPDATA = $oldHome
    Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
}
