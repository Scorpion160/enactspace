param(
    [int]$DebugPort = 9222
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")).Path
$edge = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
$profile = Join-Path $env:TEMP "enactspace-ui-audit-edge-profile"

if (-not (Test-Path $edge)) {
    throw "Microsoft Edge was not found at the audited local path."
}

$auditPids = @(Get-NetTCPConnection -LocalPort $DebugPort -State Listen -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -Unique)
foreach ($auditProcessId in $auditPids) {
    Stop-Process -Id $auditProcessId -Force -ErrorAction SilentlyContinue
}
if (Test-Path $profile) {
    Remove-Item -LiteralPath $profile -Recurse -Force
}
New-Item -ItemType Directory -Path $profile -Force | Out-Null
Start-Process -FilePath $edge -ArgumentList @(
    "--remote-debugging-port=$DebugPort",
    "--user-data-dir=$profile",
    "--disable-background-networking",
    "--disable-component-update",
    "--disable-sync",
    "--no-first-run",
    "http://127.0.0.1:18080/#/login"
) -WindowStyle Hidden

Write-Output "Edge audit profile started on CDP port $DebugPort."
