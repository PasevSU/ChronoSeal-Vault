[CmdletBinding()]
param(
  [string]$Branch = 'main',
  [int]$DebounceSeconds = 8
)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$State = Join-Path $PSScriptRoot '.watcher-state'
New-Item -ItemType Directory -Force -Path $State | Out-Null
$Log = Join-Path $State 'watcher.log'
$Lock = Join-Path $State 'sync.lock'
function Log([string]$s) { $line="$(Get-Date -Format o) $s"; Add-Content -LiteralPath $Log -Value $line; Write-Host $line }
function Ignored([string]$p) {
  if (-not $p.StartsWith($Root, [StringComparison]::OrdinalIgnoreCase)) { return $true }
  $rel = $p.Substring($Root.Length).TrimStart('\','/') -replace '\\','/'
  return ($rel -match '(^|/)\.git(/|$)' -or
          $rel -match '^tools/git-sync/\.watcher-state/' -or
          $rel -match '(^|/)(node_modules|evidence|staging|import|export|ots_generator)(/|$)' -or
          $rel -match '\.(tmp|temp|log|swp|p12|pfx|key|pem|gpg|pgp|ots|tsr|tsq)$')
}
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $Root
$watcher.IncludeSubdirectories = $true
$watcher.NotifyFilter = [IO.NotifyFilters]'FileName, DirectoryName, LastWrite, Size'
$watcher.EnableRaisingEvents = $true
$sourceId='ChronoSealVaultWatcher'
$subs=@()
$subs += Register-ObjectEvent -InputObject $watcher -EventName Changed -SourceIdentifier "$sourceId.Changed"
$subs += Register-ObjectEvent -InputObject $watcher -EventName Created -SourceIdentifier "$sourceId.Created"
$subs += Register-ObjectEvent -InputObject $watcher -EventName Deleted -SourceIdentifier "$sourceId.Deleted"
$subs += Register-ObjectEvent -InputObject $watcher -EventName Renamed -SourceIdentifier "$sourceId.Renamed"
$dirtyAt=$null
Log "Watcher started: $Root -> origin/$Branch; debounce=${DebounceSeconds}s"
try {
  while ($true) {
    $evt=Wait-Event -Timeout 2
    if ($evt) {
      $events=@($evt) + @(Get-Event | Where-Object SourceIdentifier -like "$sourceId.*")
      foreach($e in $events | Sort-Object EventIdentifier -Unique) {
        $p=$e.SourceEventArgs.FullPath
        if ($p -and -not (Ignored $p)) { $dirtyAt=Get-Date }
        Remove-Event -EventIdentifier $e.EventIdentifier -ErrorAction SilentlyContinue
      }
    }
    if ($dirtyAt -and ((Get-Date)-$dirtyAt).TotalSeconds -ge $DebounceSeconds) {
      $dirtyAt=$null
      if (Test-Path $Lock) { Log 'Sync already active; deferring.'; $dirtyAt=Get-Date; continue }
      New-Item -ItemType File -Force -Path $Lock | Out-Null
      try {
        Log 'Source change batch detected; validating and syncing.'
        & (Join-Path $PSScriptRoot 'Sync-ChronoSealRepo.ps1') -Branch $Branch
        if ($LASTEXITCODE -ne 0) { Log "Sync failed with exit $LASTEXITCODE" } else { Log 'Sync completed.' }
      } catch { Log "Sync blocked/failed: $($_.Exception.Message)" }
      finally { Remove-Item $Lock -Force -ErrorAction SilentlyContinue }
    }
  }
} finally {
  foreach($s in $subs) { Unregister-Event -SubscriptionId $s.Id -ErrorAction SilentlyContinue }
  Get-Event | Where-Object SourceIdentifier -like "$sourceId.*" | Remove-Event -ErrorAction SilentlyContinue
  $watcher.Dispose()
  Log 'Watcher stopped.'
}
