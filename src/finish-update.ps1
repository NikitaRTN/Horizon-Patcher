$ErrorActionPreference='Stop'
try {
    $parent=Get-Process -Id ([int]$env:HP_PARENT) -ErrorAction SilentlyContinue
    if ($parent -and -not $parent.WaitForExit(60000)) { throw 'The previous patcher did not close.' }
    $new=(Get-FileHash -LiteralPath $env:HP_TEMP -Algorithm SHA256).Hash
    if (-not [string]::Equals($new,$env:HP_NEW_HASH,[StringComparison]::OrdinalIgnoreCase)) { throw 'Downloaded update checksum changed.' }
    $old=(Get-FileHash -LiteralPath $env:HP_DEST -Algorithm SHA256).Hash
    if ([string]::Equals($old,$env:HP_NEW_HASH,[StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $env:HP_TEMP -Force
    } elseif ([string]::Equals($old,$env:HP_OLD_HASH,[StringComparison]::OrdinalIgnoreCase)) {
        [IO.File]::Replace($env:HP_TEMP,$env:HP_DEST,[System.Management.Automation.Language.NullString]::Value)
    } else { throw 'Patcher file changed during the update; it was not replaced.' }
    Start-Process -FilePath $env:HP_DEST -ArgumentList '--updated' | Out-Null
} catch {
    Remove-Item -LiteralPath $env:HP_TEMP -Force -ErrorAction SilentlyContinue
    Add-Type -AssemblyName System.Windows.Forms
    [Windows.Forms.MessageBox]::Show(('Не удалось установить обновление патчера: '+$_.Exception.Message),'Horizon Privacy Patcher','OK','Error') | Out-Null
    exit 1
}
