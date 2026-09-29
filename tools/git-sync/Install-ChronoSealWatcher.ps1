[CmdletBinding()]
param(
    [string]$TaskName = 'ChronoSeal Vault Git Watcher',
    [string]$Branch = 'main',
    [int]$PollSeconds = 5,
    [int]$DebounceSeconds = 10
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

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

try {
    Write-Host '[INSTALL] ChronoSeal Git Watcher'
    Write-Host "[INSTALL] Task: $TaskName"

    $Watcher = Convert-ToNativePath (
        [System.IO.Path]::GetFullPath(
            (Join-Path $PSScriptRoot 'Watch-ChronoSealRepo.ps1')
        )
    )

    if (-not (Test-Path -LiteralPath $Watcher -PathType Leaf)) {
        throw "WATCHER_NOT_FOUND: $Watcher"
    }

    Write-Host "[INSTALL] Watcher: $Watcher"

    # Prefer Windows PowerShell for ScheduledTasks cmdlets.
    $PowerShell = (Get-Command powershell.exe -ErrorAction Stop).Source

    if (-not (Test-Path -LiteralPath $PowerShell -PathType Leaf)) {
        throw "POWERSHELL_NOT_FOUND: $PowerShell"
    }

    Write-Host "[INSTALL] Engine: $PowerShell"

    # Scheduled Task runs in the current interactive user's context.
    $CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

    if ([string]::IsNullOrWhiteSpace($CurrentUser)) {
        throw 'CURRENT_USER_UNRESOLVED'
    }

    Write-Host "[INSTALL] User: $CurrentUser"

    $Arguments = @(
        '-NoLogo'
        '-NoProfile'
        '-NonInteractive'
        '-ExecutionPolicy Bypass'
        '-WindowStyle Hidden'
        '-File'
        "`"$Watcher`""
        '-Branch'
        "`"$Branch`""
        '-PollSeconds'
        $PollSeconds
        '-DebounceSeconds'
        $DebounceSeconds
    ) -join ' '

    Write-Host "[INSTALL] Arguments: $Arguments"

    $Action = New-ScheduledTaskAction `
        -Execute $PowerShell `
        -Argument $Arguments

    $Trigger = New-ScheduledTaskTrigger -AtLogOn `
        -User $CurrentUser

    $Settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -MultipleInstances IgnoreNew `
        -ExecutionTimeLimit ([TimeSpan]::Zero)

    $Principal = New-ScheduledTaskPrincipal `
        -UserId $CurrentUser `
        -LogonType Interactive `
        -RunLevel Limited

    # Remove stale/broken definition if one exists.
    $Existing = Get-ScheduledTask `
        -TaskName $TaskName `
        -ErrorAction SilentlyContinue

    if ($Existing) {
        Write-Host '[INSTALL] Removing existing task...'

        Stop-ScheduledTask `
            -TaskName $TaskName `
            -ErrorAction SilentlyContinue

        Unregister-ScheduledTask `
            -TaskName $TaskName `
            -Confirm:$false
    }

    Write-Host '[INSTALL] Registering task...'

    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $Action `
        -Trigger $Trigger `
        -Settings $Settings `
        -Principal $Principal `
        -Description 'Fail-closed ChronoSeal Vault Git polling watcher.' `
        -Force `
        -ErrorAction Stop |
        Out-Null

    # Independent registration verification.
    $Registered = Get-ScheduledTask `
        -TaskName $TaskName `
        -ErrorAction Stop

    if (-not $Registered) {
        throw 'TASK_REGISTRATION_VERIFICATION_FAILED'
    }

    Write-Host '[PASS] Task registered.'
    Write-Host '[INSTALL] Starting task...'

    Start-ScheduledTask `
        -TaskName $TaskName `
        -ErrorAction Stop

    Start-Sleep -Seconds 3

    $Registered = Get-ScheduledTask `
        -TaskName $TaskName `
        -ErrorAction Stop

    $Info = Get-ScheduledTaskInfo `
        -TaskName $TaskName `
        -ErrorAction Stop

    Write-Host ""
    Write-Host '========================================'
    Write-Host ' ChronoSeal Watcher Scheduled Task'
    Write-Host '========================================'
    Write-Host "Task             : $($Registered.TaskName)"
    Write-Host "State            : $($Registered.State)"
    Write-Host "Last run         : $($Info.LastRunTime)"
    Write-Host "Last result      : $($Info.LastTaskResult)"
    Write-Host "Watcher          : $Watcher"
    Write-Host "User             : $CurrentUser"
    Write-Host '========================================'

    if ($Registered.State -ne 'Running') {
        throw "TASK_NOT_RUNNING: state=$($Registered.State), result=$($Info.LastTaskResult)"
    }

    Write-Host '[PASS] Scheduled watcher registered and running.'
    exit 0
}
catch {
    Write-Error "[FAIL] Scheduled watcher installation failed: $($_.Exception.Message)"
    exit 1
}