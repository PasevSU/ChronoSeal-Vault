$ErrorActionPreference = 'Stop'

$Root = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$LogDir = Join-Path $Root 'logs'
if (!(Test-Path -LiteralPath $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}
$LauncherLog = Join-Path $LogDir 'launcher.log'

function Write-LauncherLog {
    param([string]$Message)
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    Add-Content -LiteralPath $LauncherLog -Value "[$stamp] $Message" -Encoding UTF8
}

try {
    $Node = Get-Command node -ErrorAction SilentlyContinue
    if (!$Node) {
        throw 'Node.js 18+ is required and node.exe was not found in PATH.'
    }

    $StartJs = Join-Path $Root 'start.js'
    if (!(Test-Path -LiteralPath $StartJs -PathType Leaf)) {
        throw "Self-starting JS launcher not found: $StartJs"
    }

    $VersionText = (& $Node.Source --version).Trim()
    if ($LASTEXITCODE -ne 0 -or $VersionText -notmatch '^v(\d+)\.') {
        throw "Unable to determine Node.js version: $VersionText"
    }
    if ([int]$Matches[1] -lt 18) {
        throw "Node.js 18+ is required. Detected: $VersionText"
    }

    Write-LauncherLog "Delegating complete server startup to start.js. Node=$($Node.Source), version=$VersionText"
    & $Node.Source $StartJs
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        throw "start.js exited with code $code."
    }
    exit 0
}
catch {
    try { Write-LauncherLog "ERROR: $($_.Exception.Message)" } catch {}
    Write-Error $_
    exit 1
}
