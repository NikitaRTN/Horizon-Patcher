param([Parameter(Mandatory=$true)][string]$Patcher)
$ErrorActionPreference = 'Stop'
$exe = (Resolve-Path $Patcher).Path
$process = Start-Process -FilePath $exe -ArgumentList '--gui-smoke-test' -PassThru
if (-not $process.WaitForExit(45000)) {
    $process.Kill()
    throw 'Real Rust WebView GUI smoke test timed out'
}
if ($process.ExitCode -ne 0) { throw "Real Rust WebView GUI smoke test failed: $($process.ExitCode)" }
Write-Host 'PASS: WebView rendered, showed compatible version, and handled the download click'
