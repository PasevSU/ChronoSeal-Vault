param(
    [string]$RepoPath  = "\\PASEVCLAUD\HDD (at HDD)\PROJECT\_ChronoSeal-Vault",
    [string]$Branch    = "main",
    [int]$Debounce     = 30,
    [int]$PollInterval = 5
)

$ErrorActionPreference = 'Stop'
$stateDir  = Join-Path $RepoPath ".git-sync"
$logFile   = Join-Path $stateDir "watcher.log"
$stopFile  = Join-Path $stateDir "stop"
$stateFile = Join-Path $stateDir "state.json"

function Write-Log($msg) {
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $msg"
    Add-Content -Path $logFile -Value $line -Encoding utf8
    Write-Host $line
}

function Save-State($status) {
    $obj = [ordered]@{
        pid        = $PID
        status     = $status
        started    = $script:startedAt
        lastChange = $script:lastChangeStr
        lastCommit = $script:lastCommitStr
        repoPath   = $RepoPath
        branch     = $Branch
        platform   = "windows"
    }
    $obj | ConvertTo-Json | Out-File -Encoding utf8 $stateFile
}

if (-not (Test-Path $RepoPath)) { Write-Error "Path not found: $RepoPath"; exit 1 }
Set-Location $RepoPath
if (-not (Test-Path ".git"))    { Write-Error "Not a Git repo";        exit 1 }

Remove-Item $stopFile -ErrorAction SilentlyContinue

$script:startedAt     = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
$script:lastChangeStr = "-"
$script:lastCommitStr = "-"

function Get-Snapshot {
    Get-ChildItem $RepoPath -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch '\\\.git\\' -and
            $_.FullName -notmatch '\\\.git-sync\\'
        } |
        ForEach-Object { "{0}|{1}|{2}" -f $_.FullName, $_.LastWriteTimeUtc.Ticks, $_.Length }
}

Write-Log "START watcher (PID=$PID) over $RepoPath"
Save-State "running"

$lastSnap   = Get-Snapshot
$lastChange = Get-Date

while ($true) {
    if (Test-Path $stopFile) {
        Write-Log "Stop marker received, exiting."
        Save-State "stopped"
        Remove-Item $stopFile -ErrorAction SilentlyContinue
        exit 0
    }

    Start-Sleep -Seconds $PollInterval

    if (Test-Path $stopFile) { continue }

    $currSnap = Get-Snapshot
    $same = ($lastSnap.Count -eq $currSnap.Count) -and
            (-not (Compare-Object $lastSnap $currSnap))

    if (-not $same) {
        $lastSnap = $currSnap
        $lastChange = Get-Date
        $script:lastChangeStr = $lastChange.ToString('yyyy-MM-dd HH:mm:ss')
        Write-Log "Change detected, waiting..."
        Save-State "running"
        continue
    }

    if (((Get-Date) - $lastChange).TotalSeconds -lt $Debounce) { continue }

    Set-Location $RepoPath
    if (-not (git status --porcelain)) { $lastChange = Get-Date; continue }

    Write-Log "Commit..."
    git add -A
    git commit -m "auto-sync: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-Null
    if ($LASTEXITCODE -eq 0) {
        git push origin $Branch 2>&1 | ForEach-Object { Write-Log "  $_" }
        $script:lastCommitStr = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        Write-Log "Push done"
        Save-State "running"
    }
    $lastChange = Get-Date
}
