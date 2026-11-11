$ErrorActionPreference = 'Stop'
$source = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '..\src\gui.ps1'), [Text.Encoding]::UTF8)
$end = '[Windows.Forms.Application]::Run($form)'
if (-not $source.Contains($end)) { throw 'GUI entry point not found' }
if (-not $source.Contains('$download.Add_Click({ OpenOfficialSetup })')) { throw 'Download button is not wired to the official link' }
$checks = @'
if ($hasCompatibleSetup -ne $script:expectedEnabled -or $download.Enabled -ne $script:expectedEnabled) { throw 'Unexpected download button state' }
if ($script:expectedEnabled -and $compatibleLabel.Text -ne 'Horizon 0.2.59  /  x64') { throw 'Wrong compatible version label' }
if (-not $script:expectedEnabled -and $compatibleLabel.Text -match '0\.2\.59') { throw 'Displayed an unverified version' }
$form.StartPosition = 'Manual'
$form.Location = New-Object Drawing.Point(-30000,-30000)
$form.ShowInTaskbar = $false
$form.Show()
[Windows.Forms.Application]::DoEvents()
SetBusy $true
if ($download.Enabled -ne $script:expectedEnabled) { throw 'Launcher scan disabled the download button' }
$download.PerformClick()
if ($script:expectedEnabled -and $script:opened -cne $env:HORIZON_SETUP_URL) { throw 'Wrong installer URL' }
if (-not $script:expectedEnabled -and $script:opened) { throw 'Opened an unsafe or unknown URL' }
$form.Dispose()
'@
$source = [regex]::Replace($source, '\$form\.Add_Shown\(\{ StartWorker .scan. \}\)', '')
$source = $source.Replace($end, $checks)
function Start-Process { param([string]$FilePath) $script:opened = $FilePath }
try {
    $url='https://github.com/horizon-rust/horizon/releases/download/launcher%400.2.59/horizon-launcher-setup.exe'
    foreach ($case in @(
        @{version='0.2.59'; url=$url; enabled=$true},
        @{version=''; url=''; enabled=$false},
        @{version='0.2.59'; url='https://evil.example/setup.exe'; enabled=$false},
        @{version='0.2.59/evil'; url=$url; enabled=$false}
    )) {
        $env:HORIZON_PATCHER_VERSION=$case.version; $env:HORIZON_SETUP_URL=$case.url
        $script:expectedEnabled=$case.enabled; $script:opened=$null
        & ([ScriptBlock]::Create($source))
    }
    Write-Host 'PASS: compatible version, official setup URL, and invalid values'
} finally {
    Remove-Item Env:HORIZON_PATCHER_VERSION, Env:HORIZON_SETUP_URL -ErrorAction SilentlyContinue
}
