$ErrorActionPreference='Stop'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
[Console]::OutputEncoding=New-Object System.Text.UTF8Encoding
$r=Invoke-RestMethod -TimeoutSec 15 -Uri $env:PATCH_API -Headers @{'User-Agent'='Horizon-Patcher'}
$a=@($r.assets | Where-Object {$_.name -eq 'HorizonPatcher.exe'})
if($a.Count -ne 1 -or $a[0].digest -notmatch '^sha256:[0-9a-fA-F]{64}$' -or $a[0].size -le 0 -or $a[0].size -gt 157286400){throw 'No verifiable update asset'}
@{tag=$r.tag_name; url=$a[0].browser_download_url; digest=$a[0].digest} | ConvertTo-Json -Compress
