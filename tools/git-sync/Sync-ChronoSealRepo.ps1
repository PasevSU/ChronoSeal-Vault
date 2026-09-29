[CmdletBinding()]
param(
  [string]$Branch = 'main',
  [string]$Message = '',
  [switch]$SkipPull
)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $Root
if (-not (Test-Path '.git')) { throw 'This folder is not initialized as a Git repository.' }
& (Join-Path $PSScriptRoot 'Test-ChronoSealRepo.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Validation failed; commit/push blocked.' }

if (-not $SkipPull) {
  git fetch origin $Branch
  if ($LASTEXITCODE -ne 0) { throw 'git fetch failed.' }
  git rev-parse --verify "origin/$Branch" *> $null
  if ($LASTEXITCODE -eq 0) {
    $behind = [int](git rev-list --count "HEAD..origin/$Branch")
    $ahead  = [int](git rev-list --count "origin/$Branch..HEAD")
    if ($behind -gt 0 -and $ahead -gt 0) { throw "Local and origin/$Branch diverged. Automatic push stopped for manual reconciliation." }
    if ($behind -gt 0) {
      git pull --ff-only origin $Branch
      if ($LASTEXITCODE -ne 0) { throw 'Fast-forward pull failed.' }
    }
  }
}

git add -A
if ($LASTEXITCODE -ne 0) { throw 'git add failed.' }
$pending = git status --porcelain
if (-not $pending) { Write-Host 'No source changes to publish.'; exit 0 }

# Defense-in-depth: refuse staged sensitive/runtime files even if .gitignore is edited.
$staged = git diff --cached --name-only
$blocked = $staged | Where-Object {
  $_ -match '(^|/)(evidence|staging|import|export|ots_generator)(/|$)' -or
  $_ -match '\.(p12|pfx|key|pem|gpg|pgp|ots|tsr|tsq)$'
}
if ($blocked) {
  git reset
  throw "Blocked sensitive/runtime paths from commit: $($blocked -join ', ')"
}
if (-not $Message) { $Message = 'Auto-sync ChronoSeal Vault ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss K') }
git commit -m $Message
if ($LASTEXITCODE -ne 0) { throw 'git commit failed.' }
git push origin $Branch
if ($LASTEXITCODE -ne 0) { throw 'git push failed.' }
Write-Host "Published commit $(git rev-parse --short HEAD) to origin/$Branch"
