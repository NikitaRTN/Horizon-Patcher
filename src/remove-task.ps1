$ErrorActionPreference='Stop'
$task=Get-ScheduledTask -TaskName $env:PATCH_TASK -TaskPath '\' -ErrorAction SilentlyContinue
if ($null -eq $task) { exit 0 }
$a=@($task.Actions)
if($a.Count -ne 1){throw 'Task action is not managed by Horizon Patcher'}
$p=[IO.Path]::GetFullPath(([string]$a[0].Execute).Trim('"'))
$dir=[IO.Path]::GetFullPath($env:PATCH_DIR)
$name=[IO.Path]::GetFileName($p)
$expected='--watch "'+$env:PATCH_TARGET+'"'
if(-not [string]::Equals([IO.Path]::GetDirectoryName($p),$dir,[StringComparison]::OrdinalIgnoreCase) -or $name -notmatch '^updater(?:-[0-9a-f]{64})?\.exe$' -or $a[0].Arguments -ne $expected){throw 'Task action is not managed by Horizon Patcher'}
Unregister-ScheduledTask -TaskName $env:PATCH_TASK -TaskPath '\' -Confirm:$false
exit 0
