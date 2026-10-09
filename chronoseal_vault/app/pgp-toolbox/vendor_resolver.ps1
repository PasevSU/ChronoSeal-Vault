# PasevSU vendor / _crypto resolver v2.1.1
# Shared by start.ps1 and setup_vendor.ps1. No network access is performed here.

function Resolve-PasevSUCryptoHome {
    param([Parameter(Mandatory=$true)][string]$ProjectRoot)

    $candidates = New-Object System.Collections.Generic.List[object]
    if ($env:PASEVSU_CRYPTO_HOME) {
        $candidates.Add([pscustomobject]@{ Kind='environment'; Path=$env:PASEVSU_CRYPTO_HOME })
    }

    $parent = Split-Path -Parent $ProjectRoot
    if ($parent) {
        $candidates.Add([pscustomobject]@{ Kind='sibling'; Path=(Join-Path $parent '_crypto') })
    }
    $candidates.Add([pscustomobject]@{ Kind='project-local'; Path=(Join-Path $ProjectRoot '_crypto') })

    $link = Join-Path $ProjectRoot '_crypto.lnk'
    if (Test-Path -LiteralPath $link -PathType Leaf) {
        try {
            $shell = New-Object -ComObject WScript.Shell
            $shortcut = $shell.CreateShortcut($link)
            if ($shortcut.TargetPath) {
                $candidates.Add([pscustomobject]@{ Kind='shortcut'; Path=$shortcut.TargetPath })
            }
        } catch {
            # Shortcut resolution is optional; continue with deterministic candidates.
        }
    }

    foreach ($candidate in $candidates) {
        if ($candidate.Path -and (Test-Path -LiteralPath $candidate.Path -PathType Container)) {
            try { $resolved = (Resolve-Path -LiteralPath $candidate.Path).Path } catch { $resolved = $candidate.Path }
            return [pscustomobject]@{ Found=$true; Kind=$candidate.Kind; Path=$resolved }
        }
    }
    return [pscustomobject]@{ Found=$false; Kind='none'; Path=$null }
}

function Get-PasevSUFileSha256 {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Write-PasevSUVendorAudit {
    param(
        [Parameter(Mandatory=$true)][string]$ProjectRoot,
        [Parameter(Mandatory=$true)][hashtable]$Record
    )
    $logDir = Join-Path $ProjectRoot 'logs'
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $Record.timestamp = (Get-Date).ToUniversalTime().ToString('o')
    $json = $Record | ConvertTo-Json -Compress -Depth 6
    Add-Content -LiteralPath (Join-Path $logDir 'vendor-resolver.jsonl') -Value $json -Encoding UTF8
}

function Copy-PasevSULocalVendor {
    param(
        [Parameter(Mandatory=$true)][string]$ProjectRoot,
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string]$Source,
        [Parameter(Mandatory=$true)][string]$Destination,
        [int]$MinBytes = 1000,
        [string]$Provider = 'local'
    )

    if (!(Test-Path -LiteralPath $Source -PathType Leaf)) { return $false }
    $srcInfo = Get-Item -LiteralPath $Source
    if ($srcInfo.Length -lt $MinBytes) { return $false }

    $srcHash = Get-PasevSUFileSha256 -Path $Source
    $dstHashBefore = Get-PasevSUFileSha256 -Path $Destination
    $changed = ($srcHash -ne $dstHashBefore)
    if ($changed) {
        $destDir = Split-Path -Parent $Destination
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
        Copy-Item -LiteralPath $Source -Destination $Destination -Force
    }
    $dstHashAfter = Get-PasevSUFileSha256 -Path $Destination
    if ($dstHashAfter -ne $srcHash) { throw "SHA-256 verification failed while installing $Name." }
    Set-Content -LiteralPath ($Destination + '.sha256') -Value $srcHash -Encoding ASCII

    Write-PasevSUVendorAudit -ProjectRoot $ProjectRoot -Record @{
        event='vendor-sync'; name=$Name; provider=$Provider; source=$Source; destination=$Destination;
        sourceSha256=$srcHash; destinationSha256Before=$dstHashBefore; destinationSha256After=$dstHashAfter;
        bytes=$srcInfo.Length; changed=$changed; verified=$true
    }
    Write-Host "[OK] $Name from $Provider ($($srcInfo.Length) bytes, SHA-256 $srcHash)"
    return $true
}
