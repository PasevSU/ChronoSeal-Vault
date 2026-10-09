param(
    [Parameter(Position=0)]
    [ValidateSet("start","stop","status","logs","restart","help")]
    [string]$Command = "help",

    [Parameter(Position=1)]
    [string]$Arg1 = "",

    [string]$RepoPath = "\\PASEVCLAUD\HDD (at HDD)\PROJECT\_ChronoSeal-Vault",

    [int]$Tail = 20
)

$stateDir  = Join-Path $RepoPath ".git-sync"
$stateFile = Join-Path $stateDir "state.json"
$logFile   = Join-Path $stateDir "watcher.log"
$stopFile  = Join-Path $stateDir "stop"
$ps1       = Join-Path $RepoPath "ha-git-sync.ps1"

function Get-State {
    if (-not (Test-Path $stateFile)) { return $null }
    try {
        $raw = Get-Content $stateFile -Raw
        if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
        $obj = $raw | ConvertFrom-Json
        if ($obj -is [array]) { return $null }
        if (-not $obj.pid) { return $null }
        return $obj
    } catch { return $null }
}

function Test-Alive($pid_) {
    if (-not $pid_) { return $false }
    try { Get-Process -Id $pid_ -ErrorAction Stop | Out-Null; return $true }
    catch { return $false }
}

switch ($Command) {
    "start" {
        $st = Get-State
        if ($st -and (Test-Alive $st.pid) -and $st.status -eq "running") {
            Write-Host "Already running (PID=$($st.pid))." -ForegroundColor Yellow
            return
        }
        Remove-Item $stopFile -ErrorAction SilentlyContinue

        $argLine = "-NoProfile -ExecutionPolicy Bypass -File `"$ps1`" -RepoPath `"$RepoPath`""
        $proc = Start-Process -FilePath "powershell.exe" `
            -ArgumentList $argLine -WindowStyle Hidden -PassThru

        Write-Host "Started watcher (PID=$($proc.Id))." -ForegroundColor Green
        Start-Sleep -Seconds 3
        if (-not (Test-Alive $proc.Id)) {
            Write-Host "Watcher died immediately!" -ForegroundColor Red
            Write-Host "Check log: $logFile" -ForegroundColor Yellow
        } else {
            Write-Host "Watcher is running." -ForegroundColor Green
        }
    }
    "stop" {
        $st = Get-State
        if (-not $st -or -not (Test-Alive $st.pid)) {
            Write-Host "Not running." -ForegroundColor Yellow
            return
        }
        "stop" | Out-File -Encoding utf8 $stopFile
        Write-Host "Stop marker sent. Waiting..."
        for ($i=0; $i -lt 15; $i++) {
            Start-Sleep -Seconds 1
            if (-not (Test-Alive $st.pid)) { Write-Host "Stopped." -ForegroundColor Green; return }
        }
        Write-Host "Graceful stop failed, killing PID $($st.pid)..." -ForegroundColor Yellow
        Stop-Process -Id $st.pid -Force -ErrorAction SilentlyContinue
    }
    "status" {
        $st = Get-State
        if (-not $st) { Write-Host "No state. Watcher never started."; return }
        $alive = Test-Alive $st.pid
        Write-Host "=== Status ==="
        Write-Host "PID:             $($st.pid)  (alive: $alive)"
        Write-Host "State:           $($st.status)"
        Write-Host "Started:         $($st.started)"
        Write-Host "Last change:     $($st.lastChange)"
        Write-Host "Last commit:     $($st.lastCommit)"
        Write-Host "Repo:            $($st.repoPath)"
        Write-Host "Branch:          $($st.branch)"
    }
    "logs" {
        if ($Arg1 -match '^\d+$') { $Tail = [int]$Arg1 }
        if (-not (Test-Path $logFile)) { Write-Host "No log."; return }
        Get-Content $logFile -Tail $Tail
    }
    "restart" {
        & $PSCommandPath stop
        Start-Sleep 2
        & $PSCommandPath start
    }
    default {
        Write-Host "Usage: git-sync.ps1 <start|stop|status|logs|restart> [N]"
        Write-Host "Example: .\git-sync.ps1 logs 50"
    }
}
