$ErrorActionPreference = 'Stop'

$Root = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$PidFile = Join-Path $Root 'logs\server.pid'
$HealthUrl = 'http://127.0.0.1:3000/api/health'

if (!(Test-Path -LiteralPath $PidFile)) {
    Write-Host 'No PasevSU PGP PID file was found. The managed server is not running.'
    exit 0
}

$ServerPid = 0
if (![int]::TryParse((Get-Content -LiteralPath $PidFile -Raw).Trim(), [ref]$ServerPid)) {
    Remove-Item -LiteralPath $PidFile -Force -ErrorAction SilentlyContinue
    throw 'Invalid PasevSU PGP PID file.'
}

$proc = Get-Process -Id $ServerPid -ErrorAction SilentlyContinue
if (!$proc) {
    Remove-Item -LiteralPath $PidFile -Force -ErrorAction SilentlyContinue
    Write-Host 'PasevSU PGP server process is no longer running.'
    exit 0
}

# Validate the process command line before terminating a PID that may have been reused.
$serverEntry = Join-Path (Join-Path $Root 'server') 'server.js'
$cim = Get-CimInstance Win32_Process -Filter "ProcessId = $ServerPid" -ErrorAction SilentlyContinue
if (!$cim -or !$cim.CommandLine -or $cim.CommandLine.IndexOf($serverEntry, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
    throw "PID $ServerPid does not match this PasevSU PGP server. Refusing to terminate it."
}

Stop-Process -Id $ServerPid -Force
Remove-Item -LiteralPath $PidFile -Force -ErrorAction SilentlyContinue
Write-Host "PasevSU PGP server stopped (PID $ServerPid)."
