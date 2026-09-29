[CmdletBinding()]
param(
    [string]$Branch = 'main',
    [ValidateRange(2,3600)]
    [int]$PollSeconds = 5,

    [ValidateRange(2,3600)]
    [int]$DebounceSeconds = 10
)

$ErrorActionPreference = 'Stop'

function Convert-ToNativePath {
    param([Parameter(Mandatory)][string]$Path)

    $Prefix = 'Microsoft.PowerShell.Core\FileSystem::'

    if ($Path.StartsWith(
        $Prefix,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        return $Path.Substring($Prefix.Length)
    }

    return $Path
}

$Root = Convert-ToNativePath (
    [System.IO.Path]::GetFullPath(
        (Join-Path $PSScriptRoot '..\..')
    )
)

$StateRoot = Join-Path `
    $env:LOCALAPPDATA `
    'ChronoSeal-Vault\git-watcher'

New-Item `
    -ItemType Directory `
    -Force `
    -Path $StateRoot |
    Out-Null

$LogFile  = Join-Path $StateRoot 'watcher.log'
$LockFile = Join-Path $StateRoot 'sync.lock'

function Write-WatcherLog {
    param([Parameter(Mandatory)][string]$Message)

    $Line = '{0} {1}' -f (Get-Date -Format o), $Message

    Add-Content `
        -LiteralPath $LogFile `
        -Value $Line `
        -Encoding UTF8

    Write-Host $Line
}

function Get-RepositoryFingerprint {

    $Status = @(
        git -C $Root status `
            --porcelain=v1 `
            --untracked-files=all
    )

    if ($LASTEXITCODE -ne 0) {
        throw 'GIT_STATUS_FAILED'
    }

    # Ignore paths that must never trigger publication.
    $Relevant = @(
        $Status |
        Where-Object {
            $_ -notmatch 'tools/git-sync/\.watcher-state' -and
            $_ -notmatch '(^|[ /])(evidence|staging|import|export|ots_generator)(/|$)'
        } |
        Sort-Object
    )

    if ($Relevant.Count -eq 0) {
        return ''
    }

    $Text = $Relevant -join "`n"

    $Bytes = [Text.Encoding]::UTF8.GetBytes($Text)

    $SHA = [Security.Cryptography.SHA256]::Create()

    try {
        return [Convert]::ToHexString(
            $SHA.ComputeHash($Bytes)
        )
    }
    finally {
        $SHA.Dispose()
    }
}

function Invoke-ChronoSealSync {

    if (Test-Path -LiteralPath $LockFile) {
        Write-WatcherLog 'LOCKED sync already active'
        return
    }

    New-Item `
        -ItemType File `
        -Force `
        -Path $LockFile |
        Out-Null

    try {
        Write-WatcherLog 'SYNC_BEGIN'

        & (Join-Path `
            $PSScriptRoot `
            'Sync-ChronoSealRepo.ps1') `
            -Branch $Branch

        if ($LASTEXITCODE -ne 0) {
            throw "SYNC_EXIT_$LASTEXITCODE"
        }

        Write-WatcherLog 'SYNC_PASS'
    }
    catch {
        Write-WatcherLog (
            'SYNC_BLOCKED {0}' -f $_.Exception.Message
        )
    }
    finally {
        Remove-Item `
            -LiteralPath $LockFile `
            -Force `
            -ErrorAction SilentlyContinue
    }
}

Set-Location -LiteralPath $Root

git rev-parse --is-inside-work-tree *> $null

if ($LASTEXITCODE -ne 0) {
    throw "NOT_A_GIT_REPOSITORY: $Root"
}

$LastFingerprint = Get-RepositoryFingerprint
$PendingFingerprint = $null
$DirtySince = $null

Write-WatcherLog (
    "START mode=polling root=$Root branch=$Branch " +
    "poll=${PollSeconds}s debounce=${DebounceSeconds}s"
)

try {

    while ($true) {

        Start-Sleep -Seconds $PollSeconds

        try {
            $CurrentFingerprint = Get-RepositoryFingerprint
        }
        catch {
            Write-WatcherLog (
                'POLL_FAIL {0}' -f $_.Exception.Message
            )
            continue
        }

        if ([string]::IsNullOrEmpty($CurrentFingerprint)) {

            $LastFingerprint = ''
            $PendingFingerprint = $null
            $DirtySince = $null

            continue
        }

        if ($CurrentFingerprint -ne $PendingFingerprint) {

            $PendingFingerprint = $CurrentFingerprint
            $DirtySince = Get-Date

            Write-WatcherLog (
                "CHANGE fingerprint=$CurrentFingerprint"
            )

            continue
        }

        if ($null -eq $DirtySince) {
            $DirtySince = Get-Date
            continue
        }

        $StableSeconds = (
            (Get-Date) - $DirtySince
        ).TotalSeconds

        if ($StableSeconds -lt $DebounceSeconds) {
            continue
        }

        Write-WatcherLog (
            "STABLE ${StableSeconds}s; starting synchronization"
        )

        Invoke-ChronoSealSync

        # Re-read actual repository state after sync.
        $AfterFingerprint = Get-RepositoryFingerprint

        if ([string]::IsNullOrEmpty($AfterFingerprint)) {

            Write-WatcherLog 'CLEAN repository synchronized'

            $LastFingerprint = ''
            $PendingFingerprint = $null
            $DirtySince = $null
        }
        else {
            # Something remains dirty. Do not claim success.
            Write-WatcherLog (
                "DIRTY_AFTER_SYNC fingerprint=$AfterFingerprint"
            )

            $LastFingerprint = $AfterFingerprint
            $PendingFingerprint = $AfterFingerprint
            $DirtySince = Get-Date
        }
    }
}
finally {
    Write-WatcherLog 'STOP'
}