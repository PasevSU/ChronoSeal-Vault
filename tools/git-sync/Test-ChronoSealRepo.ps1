[CmdletBinding()]
param(
    [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'

function Get-NativePath {
    param([Parameter(Mandatory)][string]$Path)

    if ($Path -like 'Microsoft.PowerShell.Core\FileSystem::*') {
        return $Path.Substring(
            'Microsoft.PowerShell.Core\FileSystem::'.Length
        )
    }

    return $Path
}

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Join-Path $PSScriptRoot '..\..'
}

$RepoRoot = Get-NativePath $RepoRoot
$RepoRoot = [System.IO.Path]::GetFullPath($RepoRoot)

$AddonRoot = Join-Path $RepoRoot 'chronoseal_vault'

function Invoke-Checked {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Action
    )

    Write-Host "[CHECK] $Name"

    & $Action

    if ($LASTEXITCODE -ne 0) {
        throw "[FAIL] $Name (exit code $LASTEXITCODE)"
    }

    Write-Host "[PASS] $Name"
}

Write-Host ""
Write-Host "ChronoSeal Vault repository validation"
Write-Host "Repository : $RepoRoot"
Write-Host "Application: $AddonRoot"
Write-Host ""

$Required = @(
    (Join-Path $RepoRoot 'repository.yaml'),
    (Join-Path $RepoRoot 'README.md'),
    (Join-Path $AddonRoot 'config.yaml'),
    (Join-Path $AddonRoot 'Dockerfile'),
    (Join-Path $AddonRoot 'server.js'),
    (Join-Path $AddonRoot 'package.json'),
    (Join-Path $AddonRoot 'RELEASE_MANIFEST.json'),
    (Join-Path $AddonRoot '_crypto.7z')
)

foreach ($File in $Required) {
    if (-not (Test-Path -LiteralPath $File -PathType Leaf)) {
        throw "[FAIL] Required file missing: $File"
    }
}

Write-Host "[PASS] Required repository files"

$Python = Get-Command python -ErrorAction Stop
$Node   = Get-Command node   -ErrorAction Stop

Invoke-Checked 'Home Assistant repository structure' {
    & $Python.Source `
        (Join-Path $RepoRoot 'tools\validate_repository.py') `
        $RepoRoot
}

Invoke-Checked 'ChronoSeal release gate' {
    & $Python.Source `
        (Join-Path $AddonRoot 'tools\release_gate.py')
}

$Completeness = Join-Path $AddonRoot 'tools\package_completeness.js'

if (-not (Test-Path -LiteralPath $Completeness -PathType Leaf)) {
    throw "[FAIL] Required validator missing: $Completeness"
}

Invoke-Checked 'Package completeness' {
    & $Node.Source $Completeness
}

$JsFiles = Get-ChildItem `
    -LiteralPath $AddonRoot `
    -Recurse `
    -File `
    -Filter '*.js' |
    Where-Object {
        $_.FullName -notmatch '[\\/](node_modules|vendor)[\\/]'
    }

foreach ($File in $JsFiles) {
    Invoke-Checked "JavaScript syntax: $($File.Name)" {
        & $Node.Source --check $File.FullName
    }
}

Write-Host ""
Write-Host "========================================"
Write-Host " ChronoSeal source validation: PASS"
Write-Host "========================================"
Write-Host ""

exit 0