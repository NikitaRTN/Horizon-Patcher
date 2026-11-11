param([Parameter(Mandatory=$true)][string]$Source)
$ErrorActionPreference = 'Stop'
if (Test-Path (Join-Path $Source 'smart_updates.rs')) { throw 'Patcher version integration must not be in the launcher' }
$files = @(Get-ChildItem -LiteralPath $Source -Filter '*.rs' -File -Recurse)
if ($files.Count -eq 0) { throw 'No launcher Rust sources found' }
foreach ($file in $files) {
    $text = [IO.File]::ReadAllText($file.FullName)
    foreach ($term in @('patcher_compatibility', 'PatcherCompatibility', 'patcher_update_card', 'smart_updates')) {
        if ($text.Contains($term)) { throw "Unexpected patcher UI in $($file.FullName): $term" }
    }
}
Write-Host 'PASS: patcher download UI is absent from the launcher'
