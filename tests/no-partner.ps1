param([Parameter(Mandatory = $true)][string]$Source)
$ErrorActionPreference = 'Stop'
# Detect the known render entry points and IDs across all launcher source files.
# Keep the unused partner module itself: it contains the original definitions.
$pattern = '\bpartner::(?:card|banner|banner_image|hide_button)\s*\(|\bglass_sculk\s*\(|"partner-(?:side|servers|hide)'
foreach ($sample in @('partner::card(', 'super::partner::banner(', 'partner::banner_image(', 'self.glass_sculk(', '"partner-side"')) {
    if ($sample -notmatch $pattern) { throw "Banner guard missed test input: $sample" }
}
if ('self.links.discord' -match $pattern) { throw 'Banner guard produced a false positive' }
foreach ($required in @('frame.rs', 'main.rs', 'servers_page.rs', 'glass_servers.rs')) {
    if (-not (Test-Path (Join-Path $Source $required) -PathType Leaf)) { throw "Missing expected UI source: $required" }
}
$files = @(Get-ChildItem -Path $Source -Recurse -File -Filter '*.rs' | Where-Object { $_.Name -ne 'partner.rs' })
if ($files.Count -eq 0) { throw 'No Rust source files found' }
$hits = @($files | Select-String -Pattern $pattern)
if ($hits.Count) {
    $hits | ForEach-Object { Write-Host $_.ToString() }
    throw 'Partner banner rendering remains in launcher sources'
}
Write-Host 'No known partner banner render paths found.'
