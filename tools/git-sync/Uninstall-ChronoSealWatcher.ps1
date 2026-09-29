param([string]$TaskName='ChronoSeal Vault Git Watcher')
$ErrorActionPreference='Stop'
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
  Write-Host "Removed scheduled task: $TaskName"
} else { Write-Host 'Watcher task is not installed.' }
