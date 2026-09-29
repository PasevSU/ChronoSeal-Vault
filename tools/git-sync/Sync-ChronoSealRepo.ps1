[CmdletBinding()]
param(
    [string]$Branch = 'main',
    [string]$Message = ''
)

$ErrorActionPreference = 'Stop'

function Native-Path([string]$Path) {
    $prefix = 'Microsoft.PowerShell.Core\FileSystem::'
    if ($Path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        return $Path.Substring($prefix.Length)
    }
    return $Path
}

$Root = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '..\..')
)
$Root = Native-Path $Root

Set-Location -LiteralPath $Root

if (-not (Test-Path -LiteralPath (Join-Path $Root '.git'))) {
    throw 'This folder is not initialized as a Git repository.'
}

# Never sync from a dirty/conflicted Git operation.
$unmerged = @(git diff --name-only --diff-filter=U)
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect merge state.' }
if ($unmerged.Count -gt 0) {
    throw "UNMERGED_PATHS: $($unmerged -join ', ')"
}

Write-Host '[SYNC] Running validation...'
& (Join-Path $PSScriptRoot 'Test-ChronoSealRepo.ps1') -RepoRoot $Root
if ($LASTEXITCODE -ne 0) {
    throw 'VALIDATION_FAILED: commit/push blocked.'
}

Write-Host "[SYNC] Fetching origin/$Branch..."
git fetch origin $Branch
if ($LASTEXITCODE -ne 0) {
    throw 'FETCH_FAILED'
}

git rev-parse --verify "origin/$Branch" *> $null
$RemoteExists = ($LASTEXITCODE -eq 0)

if ($RemoteExists) {
    $BehindText = git rev-list --count "HEAD..origin/$Branch"
    if ($LASTEXITCODE -ne 0) { throw 'Unable to calculate behind count.' }

    $AheadText = git rev-list --count "origin/$Branch..HEAD"
    if ($LASTEXITCODE -ne 0) { throw 'Unable to calculate ahead count.' }

    $Behind = [int]$BehindText
    $Ahead  = [int]$AheadText

    Write-Host "[SYNC] Git state: ahead=$Ahead behind=$Behind"

    if ($Behind -gt 0) {
        throw "REMOTE_DIVERGENCE: origin/$Branch contains commits not present locally. Automatic pull/merge/rebase is forbidden."
    }
}

git add -A
if ($LASTEXITCODE -ne 0) {
    throw 'GIT_ADD_FAILED'
}

$Staged = @(git diff --cached --name-only)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to inspect staged files.'
}

if ($Staged.Count -eq 0) {
    Write-Host '[SYNC] No source changes to publish.'
    exit 0
}

# Defense in depth. .gitignore is NOT considered sufficient.
$Blocked = @(
    $Staged | Where-Object {
        $_ -match '(^|/)(evidence|staging|import|export|ots_generator)(/|$)' -or
        $_ -match '\.(p12|pfx|key|pem|gpg|pgp|ots|tsr|tsq)$'
    }
)

if ($Blocked.Count -gt 0) {
    git reset
    throw "SENSITIVE_FILE_BLOCKED: $($Blocked -join ', ')"
}

# Validate again with the exact files that are about to be committed staged.
Write-Host '[SYNC] Re-validating staged source state...'
& (Join-Path $PSScriptRoot 'Test-ChronoSealRepo.ps1') -RepoRoot $Root
if ($LASTEXITCODE -ne 0) {
    git reset
    throw 'STAGED_VALIDATION_FAILED'
}

if ([string]::IsNullOrWhiteSpace($Message)) {
    $Message = 'Auto-sync ChronoSeal Vault ' +
        (Get-Date -Format 'yyyy-MM-dd HH:mm:ss K')
}

git commit -m $Message
if ($LASTEXITCODE -ne 0) {
    throw 'COMMIT_FAILED'
}

$LocalCommit = (git rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to determine local HEAD.'
}

git push origin "HEAD:$Branch"
if ($LASTEXITCODE -ne 0) {
    throw 'PUSH_FAILED'
}

# Independent post-push verification.
git fetch origin $Branch
if ($LASTEXITCODE -ne 0) {
    throw 'POST_PUSH_FETCH_FAILED'
}

$RemoteCommit = (git rev-parse "origin/$Branch").Trim()
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to determine remote HEAD.'
}

if ($LocalCommit -ne $RemoteCommit) {
    throw "REMOTE_VERIFICATION_FAILED: local=$LocalCommit remote=$RemoteCommit"
}

Write-Host "[PASS] Published and verified $LocalCommit on origin/$Branch"
exit 0