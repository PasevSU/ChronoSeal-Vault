[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '..\..')
)

$Watcher = Join-Path $PSScriptRoot 'Watch-ChronoSealRepo.ps1'

if (-not (Test-Path -LiteralPath $Watcher -PathType Leaf)) {
    throw "Watcher not found: $Watcher"
}

$Backup = "$Watcher.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

Write-Host ""
Write-Host "ChronoSeal Watcher Repair"
Write-Host "========================="
Write-Host "Repository : $RepoRoot"
Write-Host "Watcher    : $Watcher"
Write-Host "Backup     : $Backup"
Write-Host ""

Copy-Item `
    -LiteralPath $Watcher `
    -Destination $Backup `
    -Force

Write-Host '[PASS] Backup created.'

$NewWatcher = @'
[CmdletBinding()]
param(
    [string]$Branch = 'main',

    [ValidateRange(2,3600)]
    [int]$PollSeconds = 5,

    [ValidateRange(2,3600)]
    [int]$DebounceSeconds = 10
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Convert-ToNativePath {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

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
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $Line = '{0} {1}' -f (
        Get-Date -Format o
    ), $Message

    Add-Content `
        -LiteralPath $LogFile `
        -Value $Line `
        -Encoding UTF8

    Write-Host $Line
}

#
# ------------------------------------------------------------------
# BOOTSTRAP
# ------------------------------------------------------------------
#

Write-WatcherLog (
    "BOOTSTRAP pid=$PID user=$(" +
    [System.Security.Principal.WindowsIdentity]::GetCurrent().Name +
    ")"
)

Write-WatcherLog (
    "BOOTSTRAP powershell=$($PSVersionTable.PSVersion)"
)

Write-WatcherLog "BOOTSTRAP root=$Root"

try {

    if (-not (
        Test-Path `
            -LiteralPath $Root `
            -PathType Container
    )) {
        throw "ROOT_UNREACHABLE: $Root"
    }

    Write-WatcherLog 'BOOTSTRAP root_access=PASS'

    $GitCommand = Get-Command `
        git.exe `
        -ErrorAction SilentlyContinue

    if (-not $GitCommand) {
        $GitCommand = Get-Command `
            git `
            -ErrorAction SilentlyContinue
    }

    if (-not $GitCommand) {
        throw "GIT_NOT_FOUND: PATH=$env:PATH"
    }

    $GitExe = $GitCommand.Source

    if ([string]::IsNullOrWhiteSpace($GitExe)) {
        throw 'GIT_PATH_EMPTY'
    }

    if (-not (
        Test-Path `
            -LiteralPath $GitExe `
            -PathType Leaf
    )) {
        throw "GIT_EXECUTABLE_UNREACHABLE: $GitExe"
    }

    Write-WatcherLog "BOOTSTRAP git=$GitExe"

    Set-Location -LiteralPath $Root

    Write-WatcherLog (
        "BOOTSTRAP cwd=$((Get-Location).Path)"
    )

    & $GitExe `
        rev-parse `
        --is-inside-work-tree `
        *> $null

    if ($LASTEXITCODE -ne 0) {
        throw (
            "NOT_A_GIT_REPOSITORY: " +
            "$Root exit=$LASTEXITCODE"
        )
    }

    Write-WatcherLog 'BOOTSTRAP git_repository=PASS'
}
catch {

    Write-WatcherLog (
        "BOOTSTRAP_FAIL $($_.Exception.Message)"
    )

    exit 1
}

#
# ------------------------------------------------------------------
# GIT FINGERPRINT
# ------------------------------------------------------------------
#

function Get-RepositoryFingerprint {

    $Status = @(
        & $GitExe `
            -C $Root `
            status `
            --porcelain=v1 `
            --untracked-files=all
    )

    if ($LASTEXITCODE -ne 0) {
        throw (
            "GIT_STATUS_FAILED exit=$LASTEXITCODE"
        )
    }

    $Relevant = @(
        $Status |
        Where-Object {

            $_ -notmatch `
                'tools/git-sync/\.watcher-state' `
            -and

            $_ -notmatch `
                '(^|[ /])(evidence|staging|import|export|ots_generator)(/|$)'
        } |
        Sort-Object
    )

    if ($Relevant.Count -eq 0) {
        return ''
    }

    $Text = $Relevant -join "`n"

    $Bytes = [Text.Encoding]::UTF8.GetBytes(
        $Text
    )

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

#
# ------------------------------------------------------------------
# SYNC
# ------------------------------------------------------------------
#

function Invoke-ChronoSealSync {

    if (Test-Path -LiteralPath $LockFile) {

        Write-WatcherLog `
            'LOCKED sync already active'

        return
    }

    New-Item `
        -ItemType File `
        -Force `
        -Path $LockFile |
        Out-Null

    try {

        Write-WatcherLog 'SYNC_BEGIN'

        $SyncScript = Join-Path `
            $PSScriptRoot `
            'Sync-ChronoSealRepo.ps1'

        if (-not (
            Test-Path `
                -LiteralPath $SyncScript `
                -PathType Leaf
        )) {
            throw (
                "SYNC_SCRIPT_NOT_FOUND: " +
                $SyncScript
            )
        }

        & $SyncScript `
            -Branch $Branch

        if ($LASTEXITCODE -ne 0) {

            throw (
                "SYNC_EXIT_$LASTEXITCODE"
            )
        }

        Write-WatcherLog 'SYNC_PASS'
    }
    catch {

        Write-WatcherLog (
            'SYNC_BLOCKED {0}' -f `
            $_.Exception.Message
        )
    }
    finally {

        Remove-Item `
            -LiteralPath $LockFile `
            -Force `
            -ErrorAction SilentlyContinue
    }
}

#
# ------------------------------------------------------------------
# INITIAL STATE
# ------------------------------------------------------------------
#

try {

    $LastFingerprint = `
        Get-RepositoryFingerprint
}
catch {

    Write-WatcherLog (
        "STARTUP_FAIL $($_.Exception.Message)"
    )

    exit 1
}

$PendingFingerprint = $null
$DirtySince = $null

Write-WatcherLog (
    "START mode=polling root=$Root " +
    "branch=$Branch " +
    "poll=${PollSeconds}s " +
    "debounce=${DebounceSeconds}s"
)

#
# ------------------------------------------------------------------
# POLLING LOOP
# ------------------------------------------------------------------
#

try {

    while ($true) {

        Start-Sleep `
            -Seconds $PollSeconds

        try {

            $CurrentFingerprint = `
                Get-RepositoryFingerprint
        }
        catch {

            Write-WatcherLog (
                'POLL_FAIL {0}' -f `
                $_.Exception.Message
            )

            continue
        }

        #
        # Repository clean
        #

        if (
            [string]::IsNullOrEmpty(
                $CurrentFingerprint
            )
        ) {

            $LastFingerprint    = ''
            $PendingFingerprint = $null
            $DirtySince         = $null

            continue
        }

        #
        # New/changed dirty state
        #

        if (
            $CurrentFingerprint -ne `
            $PendingFingerprint
        ) {

            $PendingFingerprint = `
                $CurrentFingerprint

            $DirtySince = Get-Date

            Write-WatcherLog (
                "CHANGE fingerprint=" +
                $CurrentFingerprint
            )

            continue
        }

        #
        # Debounce
        #

        if ($null -eq $DirtySince) {

            $DirtySince = Get-Date
            continue
        }

        $StableSeconds = (
            (Get-Date) - $DirtySince
        ).TotalSeconds

        if (
            $StableSeconds -lt `
            $DebounceSeconds
        ) {
            continue
        }

        Write-WatcherLog (
            "STABLE ${StableSeconds}s; " +
            "starting synchronization"
        )

        #
        # Publish
        #

        Invoke-ChronoSealSync

        #
        # Independent post-sync state check
        #

        try {

            $AfterFingerprint = `
                Get-RepositoryFingerprint
        }
        catch {

            Write-WatcherLog (
                "POST_SYNC_CHECK_FAIL " +
                $_.Exception.Message
            )

            $PendingFingerprint = $null
            $DirtySince = Get-Date

            continue
        }

        if (
            [string]::IsNullOrEmpty(
                $AfterFingerprint
            )
        ) {

            Write-WatcherLog `
                'CLEAN repository synchronized'

            $LastFingerprint    = ''
            $PendingFingerprint = $null
            $DirtySince         = $null
        }
        else {

            Write-WatcherLog (
                "DIRTY_AFTER_SYNC fingerprint=" +
                $AfterFingerprint
            )

            $LastFingerprint = `
                $AfterFingerprint

            $PendingFingerprint = `
                $AfterFingerprint

            $DirtySince = Get-Date
        }
    }
}
catch {

    Write-WatcherLog (
        "FATAL $($_.Exception.Message)"
    )

    exit 1
}
finally {

    Write-WatcherLog 'STOP'
}
'@

#
# Write repaired watcher
#

Set-Content `
    -LiteralPath $Watcher `
    -Value $NewWatcher `
    -Encoding UTF8

Write-Host '[PASS] Repaired watcher written.'

#
# Syntax verification using ParseInput.
# ParseFile is intentionally avoided because repository is UNC.
#

$Source = Get-Content `
    -LiteralPath $Watcher `
    -Raw `
    -ErrorAction Stop

$Tokens = $null
$Errors = $null

[System.Management.Automation.Language.Parser]::ParseInput(
    $Source,
    [ref]$Tokens,
    [ref]$Errors
) | Out-Null

if ($Errors.Count -gt 0) {

    Write-Host '[FAIL] PowerShell syntax validation'

    $Errors |
        Format-List `
            ErrorId,
            Message,
            Extent

    Write-Host '[ROLLBACK] Restoring backup...'

    Copy-Item `
        -LiteralPath $Backup `
        -Destination $Watcher `
        -Force

    throw 'WATCHER_REPAIR_SYNTAX_FAILED'
}

Write-Host '[PASS] PowerShell syntax validation.'

#
# Check required companion script.
#

$SyncScript = Join-Path `
    $PSScriptRoot `
    'Sync-ChronoSealRepo.ps1'

if (-not (
    Test-Path `
        -LiteralPath $SyncScript `
        -PathType Leaf
)) {
    throw "Missing sync script: $SyncScript"
}

Write-Host '[PASS] Sync script present.'

Write-Host ""
Write-Host '========================================'
Write-Host ' ChronoSeal Watcher Repair: PASS'
Write-Host '========================================'
Write-Host "Watcher : $Watcher"
Write-Host "Backup  : $Backup"
Write-Host '========================================'