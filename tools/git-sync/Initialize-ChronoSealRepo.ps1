[CmdletBinding()]
param(
  [Parameter(Mandatory=$false)][string]$RepoUrl = "https://github.com/PasevSU/ChronoSeal-Vault.git",
  [Parameter(Mandatory=$false)][string]$Branch = "main"
)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $Root

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'git.exe is required.' }

if (-not (Test-Path '.git')) {
  git init -b $Branch
  if ($LASTEXITCODE -ne 0) { throw 'git init failed.' }
}

$origin = git remote get-url origin 2>$null
if ($LASTEXITCODE -eq 0 -and $origin) {
  if ($origin.Trim() -ne $RepoUrl) {
    git remote set-url origin $RepoUrl
    if ($LASTEXITCODE -ne 0) { throw 'git remote set-url failed.' }
  }
} else {
  git remote add origin $RepoUrl
  if ($LASTEXITCODE -ne 0) { throw 'git remote add origin failed.' }
}

Write-Host "Repository root : $Root"
Write-Host "Origin          : $(git remote get-url origin)"
Write-Host "Branch          : $Branch"
Write-Host ''
Write-Host 'Running source validation before first commit...'
& (Join-Path $PSScriptRoot 'Test-ChronoSealRepo.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Repository validation failed. Nothing was pushed.' }

git add -A
if ($LASTEXITCODE -ne 0) { throw 'git add failed.' }
$changes = git status --porcelain
if ($changes) {
  git commit -m "Initialize ChronoSeal Vault repository"
  if ($LASTEXITCODE -ne 0) { throw 'git commit failed. Configure git user.name/user.email if needed.' }
}

# If the remote is empty this succeeds. If it already contains work, stop instead
# of rewriting history; user can reconcile explicitly.
git ls-remote --exit-code --heads origin $Branch *> $null
$remoteBranchExists = ($LASTEXITCODE -eq 0)
if ($remoteBranchExists) {
  Write-Warning "origin/$Branch already exists. Initialization did not overwrite remote history."
  Write-Host "Run: git fetch origin; git status; then reconcile before enabling the watcher."
  exit 2
}

git push -u origin $Branch
if ($LASTEXITCODE -ne 0) { throw 'Initial push failed.' }
Write-Host 'Initial repository publication completed.'
