[CmdletBinding()]
param(
    [string]$Branch = 'main',
    [int]$DebounceSeconds = 8
)

$ErrorActionPreference = 'Stop'

function Native-Path([string]$Path) {
    $prefix = 'Microsoft.PowerShell.Core\FileSystem::'
    if ($Path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        return $Path.Substring($prefix.Length)
    }
    return $Path
}

$Root = Native-Path (
    [System.IO.Path]::GetFullPath(
        (Join-Path $PSScriptRoot '..\..')
    )
)

$State = Join-Path $env:LOCALAPPDATA 'ChronoSeal-Vault\git-watcher'
New-Item -ItemType Directory -Force -Path $State | Out-Null

$Log  = Join-Path $State 'watcher.log'
$Lock = Join-Path $State 'sync.lock'

function Write-WatcherLog([string]$Text) {
    $Line = "$(Get-Date -Format o) $Text"
    Add-Content -LiteralPath $Log -Value $Line -Encoding UTF8
    Write-Host $Line
}

function Test-Ignored([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $true
    }

    if (-not $Path.StartsWith(
        $Root,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        return $true
    }

    $Relative = $Path.Substring($Root.Length).
        TrimStart('\','/') -replace '\\','/'

    return (
        $Relative -match '(^|/)\.git(/|$)' -or
        $Relative -match '(^|/)(node_modules|evidence|staging|import|export|ots_generator)(/|$)' -or
        $Relative -match '\.(tmp|temp|log|swp|p12|pfx|key|pem|gpg|pgp|ots|tsr|tsq)$'
    )
}

$Watcher = [System.IO.FileSystemWatcher]::new()
$Watcher.Path = $Root
$Watcher.IncludeSubdirectories = $true
$Watcher.NotifyFilter = (
    [IO.NotifyFilters]::FileName -bor
    [IO.NotifyFilters]::DirectoryName -bor
    [IO.NotifyFilters]::LastWrite -bor
    [IO.NotifyFilters]::Size
)

$SourceId = "ChronoSealVaultWatcher.$PID"

$Subscriptions = @(
    Register-ObjectEvent $Watcher Changed -SourceIdentifier "$SourceId.Changed"
    Register-ObjectEvent $Watcher Created -SourceIdentifier "$SourceId.Created"
    Register-ObjectEvent $Watcher Deleted -SourceIdentifier "$SourceId.Deleted"
    Register-ObjectEvent $Watcher Renamed -SourceIdentifier "$SourceId.Renamed"
)

$Watcher.EnableRaisingEvents = $true
$DirtyAt = $null

Write-WatcherLog "START root=$Root branch=$Branch debounce=${DebounceSeconds}s"

try {
    while ($true) {
        $Event = Wait-Event -Timeout 2

        if ($Event) {
            $Events = @($Event) + @(
                Get-Event |
                    Where-Object SourceIdentifier -Like "$SourceId.*"
            )

            foreach (
                $Current in
                ($Events | Sort-Object EventIdentifier -Unique)
            ) {
                $Path = $Current.SourceEventArgs.FullPath

                if (-not (Test-Ignored $Path)) {
                    $DirtyAt = Get-Date
                    Write-WatcherLog "CHANGE $Path"
                }

                Remove-Event `
                    -EventIdentifier $Current.EventIdentifier `
                    -ErrorAction SilentlyContinue
            }
        }

        if (
            $DirtyAt -and
            ((Get-Date) - $DirtyAt).TotalSeconds -ge $DebounceSeconds
        ) {
            $DirtyAt = $null

            if (Test-Path -LiteralPath $Lock) {
                Write-WatcherLog 'LOCKED another sync is active'
                $DirtyAt = Get-Date
                continue
            }

            New-Item -ItemType File -Path $Lock -Force | Out-Null

            try {
                Write-WatcherLog 'SYNC_BEGIN'

                & (Join-Path $PSScriptRoot 'Sync-ChronoSealRepo.ps1') `
                    -Branch $Branch

                if ($LASTEXITCODE -ne 0) {
                    Write-WatcherLog "SYNC_FAIL exit=$LASTEXITCODE"
                }
                else {
                    Write-WatcherLog 'SYNC_PASS'
                }
            }
            catch {
                Write-WatcherLog "SYNC_BLOCKED $($_.Exception.Message)"
            }
            finally {
                Remove-Item `
                    -LiteralPath $Lock `
                    -Force `
                    -ErrorAction SilentlyContinue
            }
        }
    }
}
finally {
    foreach ($Subscription in $Subscriptions) {
        Unregister-Event `
            -SubscriptionId $Subscription.Id `
            -ErrorAction SilentlyContinue
    }

    Get-Event |
        Where-Object SourceIdentifier -Like "$SourceId.*" |
        Remove-Event -ErrorAction SilentlyContinue

    $Watcher.Dispose()
    Write-WatcherLog 'STOP'
}