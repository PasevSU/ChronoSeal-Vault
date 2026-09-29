[CmdletBinding()]
param(
  [string]$TaskName = 'ChronoSeal Vault Git Watcher',
  [string]$Branch = 'main'
)
$ErrorActionPreference='Stop'
$Watcher=(Resolve-Path (Join-Path $PSScriptRoot 'Watch-ChronoSealRepo.ps1')).Path
$pwsh=(Get-Command powershell.exe -ErrorAction Stop).Source
$arg="-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Watcher`" -Branch `"$Branch`""
$action=New-ScheduledTaskAction -Execute $pwsh -Argument $arg
$trigger=New-ScheduledTaskTrigger -AtLogOn
$settings=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Description 'Validates, commits and pushes ChronoSeal Vault source changes to GitHub.' -Force | Out-Null
Start-ScheduledTask -TaskName $TaskName
Write-Host "Installed and started scheduled task: $TaskName"
