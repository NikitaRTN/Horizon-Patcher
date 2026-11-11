param([Parameter(Mandatory=$true)][string]$Source)
$ErrorActionPreference = 'Stop'
if (Test-Path (Join-Path $Source 'smart_updates.rs')) { throw 'Patcher version integration must not be in the launcher' }
foreach ($file in @('main.rs', 'backend.rs', 'lib.rs')) {
    $text = [IO.File]::ReadAllText((Join-Path (Resolve-Path $Source).Path $file))
    foreach ($term in @('patcher_compatibility', 'PatcherCompatibility', 'patcher_update_card', 'smart_updates')) {
        if ($text.Contains($term)) { throw "Unexpected patcher UI in ${file}: $term" }
    }
}
Write-Host 'PASS: patcher download UI is absent from the launcher'
