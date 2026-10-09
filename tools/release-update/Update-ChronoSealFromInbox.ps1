[CmdletBinding()]
param(
    [string]$Branch = 'main',
    [switch]$NoPush
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Native-Path([string]$Path) {
    $prefix = 'Microsoft.PowerShell.Core\FileSystem::'
    if ($Path.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { return $Path.Substring($prefix.Length) }
    return $Path
}
function Fail([string]$Message) { throw "RELEASE_UPDATE_FAIL: $Message" }
function Run-Git([string[]]$Args) {
    $out = & git @Args 2>&1
    if ($LASTEXITCODE -ne 0) { throw "GIT_FAIL: git $($Args -join ' ')`n$($out -join "`n")" }
    return @($out)
}
function Assert-CleanGit([string]$Root) {
    Set-Location -LiteralPath $Root
    $u = @(git diff --name-only --diff-filter=U)
    if ($LASTEXITCODE -ne 0) { Fail 'Unable to inspect merge state.' }
    if ($u.Count) { Fail "Unmerged paths: $($u -join ', ')" }
    $s = @(git status --porcelain --untracked-files=all | Where-Object { $_ -notmatch '^\?\? _release_inbox/' })
    if ($LASTEXITCODE -ne 0) { Fail 'Unable to inspect Git status.' }
    if ($s.Count) { Fail "Repository must be clean before update. Changes: $($s -join '; ')" }
}
function Test-Package([string]$PackageRoot) {
    $required = @(
        'repository.yaml','README.md','.gitignore','.gitattributes',
        'chronoseal_vault\config.yaml','chronoseal_vault\Dockerfile','chronoseal_vault\package.json',
        'chronoseal_vault\tools\release_gate.py','chronoseal_vault\tools\package_completeness.js',
        'tools\validate_repository.py','tools\git-sync\Test-ChronoSealRepo.ps1','tools\git-sync\Sync-ChronoSealRepo.ps1'
    )
    foreach($rel in $required) { if(-not (Test-Path -LiteralPath (Join-Path $PackageRoot $rel) -PathType Leaf)){ Fail "Archive missing required file: $rel" } }
    Push-Location $PackageRoot
    try {
        & python .\chronoseal_vault\tools\release_gate.py
        if($LASTEXITCODE -ne 0){ Fail 'Staged release_gate.py failed.' }
        & node .\chronoseal_vault\tools\package_completeness.js
        if($LASTEXITCODE -ne 0){ Fail 'Staged package_completeness.js failed.' }
        & python .\tools\validate_repository.py
        if($LASTEXITCODE -ne 0){ Fail 'Staged validate_repository.py failed.' }
    } finally { Pop-Location }
}

$Root = Native-Path ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..')))
$Inbox = Join-Path $Root '_release_inbox'
$StateRoot = Join-Path $env:LOCALAPPDATA 'ChronoSeal-Vault\git-watcher'
$LockFile = Join-Path $StateRoot 'sync.lock'
$WorkRoot = Join-Path $env:TEMP ("ChronoSeal-ReleaseUpdate-" + [guid]::NewGuid().ToString('N'))
$Stage = Join-Path $WorkRoot 'stage'
$Applied = $false
$OldHead = $null

New-Item -ItemType Directory -Force -Path $Inbox,$StateRoot,$Stage | Out-Null
$archives = @(Get-ChildItem -LiteralPath $Inbox -File -Filter '*.zip' | Where-Object { $_.Name -notmatch '\.failed\.|\.applied\.' })
if($archives.Count -ne 1){ Fail "Inbox must contain exactly one release ZIP; found $($archives.Count)." }
$Archive = $archives[0]
$ArchiveHash = (Get-FileHash -LiteralPath $Archive.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
$HashFile = $Archive.FullName + '.sha256'
if(Test-Path -LiteralPath $HashFile){
    $expected = ((Get-Content -LiteralPath $HashFile -Raw).Trim() -split '\s+')[0].ToLowerInvariant()
    if($expected -ne $ArchiveHash){ Fail "Archive SHA-256 mismatch. expected=$expected actual=$ArchiveHash" }
}
Write-Host "[UPDATE] archive=$($Archive.Name)"
Write-Host "[UPDATE] sha256=$ArchiveHash"

if(Test-Path -LiteralPath $LockFile){ Fail "Repository synchronization lock already exists: $LockFile" }
Set-Content -LiteralPath $LockFile -Value ("release-update pid={0} time={1:o}" -f $PID,(Get-Date)) -Encoding ASCII
try {
    Assert-CleanGit $Root
    $OldHead = (Run-Git @('rev-parse','HEAD'))[0].Trim()
    Write-Host "[UPDATE] current HEAD=$OldHead"

    Expand-Archive -LiteralPath $Archive.FullName -DestinationPath $Stage -Force
    $entries = @(Get-ChildItem -LiteralPath $Stage -Force)
    if($entries.Count -eq 1 -and $entries[0].PSIsContainer -and (Test-Path (Join-Path $entries[0].FullName 'chronoseal_vault'))){ $PackageRoot=$entries[0].FullName } else { $PackageRoot=$Stage }
    Write-Host '[UPDATE] validating staged release before touching repository...'
    Test-Package $PackageRoot

    # Apply only controlled source surfaces. Never touch .git, inbox or local watcher state.
    $appSrc = Join-Path $PackageRoot 'chronoseal_vault'
    $appDst = Join-Path $Root 'chronoseal_vault'
    if(Test-Path $appDst){ Remove-Item -LiteralPath $appDst -Recurse -Force }
    Copy-Item -LiteralPath $appSrc -Destination $appDst -Recurse -Force

    foreach($rel in @('repository.yaml','README.md','.gitignore','.gitattributes','LICENSE')){
        $src=Join-Path $PackageRoot $rel; if(Test-Path $src){ Copy-Item -LiteralPath $src -Destination (Join-Path $Root $rel) -Force }
    }
    foreach($dir in @('tools\git-sync','tools\release-update')){
        $src=Join-Path $PackageRoot $dir; $dst=Join-Path $Root $dir
        if(Test-Path $src){ if(Test-Path $dst){Remove-Item $dst -Recurse -Force}; New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null; Copy-Item $src $dst -Recurse -Force }
    }
    if(Test-Path (Join-Path $PackageRoot 'tools\validate_repository.py')){ Copy-Item (Join-Path $PackageRoot 'tools\validate_repository.py') (Join-Path $Root 'tools\validate_repository.py') -Force }
    $Applied=$true

    Write-Host '[UPDATE] validating applied repository...'
    & (Join-Path $Root 'tools\git-sync\Test-ChronoSealRepo.ps1') -RepoRoot $Root
    if($LASTEXITCODE -ne 0){ Fail 'Applied repository validation failed.' }

    Set-Location $Root
    git add -A
    if($LASTEXITCODE -ne 0){ Fail 'git add failed.' }
    $blocked=@(git diff --cached --name-only | Where-Object { $_ -match '(^|/)_release_inbox/' -or $_ -match '\.(zip|7z)$' -and $_ -notmatch '^chronoseal_vault/_crypto\.7z$' })
    if($blocked.Count){ git reset | Out-Null; Fail "Release/build archive would be committed: $($blocked -join ', ')" }
    $staged=@(git diff --cached --name-only)
    if(-not $staged.Count){ Write-Host '[UPDATE] release is already installed; nothing to commit.'; exit 0 }

    $version = (Get-Content (Join-Path $Root 'chronoseal_vault\config.yaml') | Select-String '^version:\s*["'']?([^"'']+)' ).Matches.Groups[1].Value.Trim()
    $msg="Release update ChronoSeal Vault $version"
    git commit -m $msg
    if($LASTEXITCODE -ne 0){ Fail 'Release commit failed.' }
    $newHead=(git rev-parse HEAD).Trim()
    Write-Host "[UPDATE] committed $newHead"

    if(-not $NoPush){
        git fetch origin $Branch
        if($LASTEXITCODE -ne 0){ Fail 'Pre-push fetch failed.' }
        $behind=[int](git rev-list --count "HEAD..origin/$Branch")
        if($LASTEXITCODE -ne 0){ Fail 'Unable to determine remote divergence.' }
        if($behind -gt 0){ Fail "Remote divergence: local is behind origin/$Branch by $behind commit(s)." }
        git push origin "HEAD:$Branch"
        if($LASTEXITCODE -ne 0){ Fail 'Push failed.' }
        git fetch origin $Branch
        if($LASTEXITCODE -ne 0){ Fail 'Post-push fetch failed.' }
        $remote=(git rev-parse "origin/$Branch").Trim()
        if($remote -ne $newHead){ Fail "Post-push verification mismatch local=$newHead remote=$remote" }
        Write-Host "[PASS] Published and independently verified $newHead on origin/$Branch"
    } else { Write-Host '[PASS] Local update committed; push skipped by -NoPush.' }

    $doneName = '{0}.applied.{1}.{2}.zip' -f [IO.Path]::GetFileNameWithoutExtension($Archive.Name),(Get-Date -Format 'yyyyMMdd-HHmmss'),$ArchiveHash.Substring(0,12)
    Rename-Item -LiteralPath $Archive.FullName -NewName $doneName
    if(Test-Path $HashFile){ Rename-Item -LiteralPath $HashFile -NewName ($doneName + '.sha256') }
    Write-Host '[PASS] ChronoSeal release update completed.'
}
catch {
    Write-Error $_
    if($Applied -and $OldHead){
        Write-Warning "Rolling repository back to $OldHead"
        Set-Location $Root
        git reset --hard $OldHead | Out-Host
        git clean -fd -- chronoseal_vault tools repository.yaml README.md .gitattributes .gitignore LICENSE | Out-Host
    }
    throw
}
finally {
    Remove-Item -LiteralPath $LockFile -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $WorkRoot -Recurse -Force -ErrorAction SilentlyContinue
}
