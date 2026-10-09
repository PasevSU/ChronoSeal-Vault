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
            Write-Host "Вече работи (PID=$($st.pid))." -ForegroundColor Yellow
            return
        }
        Remove-Item $stopFile -ErrorAction SilentlyContinue

        # ⬇️ Подаваме ЕДИН низ с вградени кавички — оцеляват интервали и скоби
        $argLine = "-NoProfile -ExecutionPolicy Bypass -File `"$ps1`" -RepoPath `"$RepoPath`""

        $proc = Start-Process -FilePath "powershell.exe" `
            -ArgumentList $argLine `
            -WindowStyle Hidden -PassThru

        Write-Host "Стартиран watcher (PID=$($proc.Id))." -ForegroundColor Green
        Start-Sleep -Seconds 3

        if (-not (Test-Alive $proc.Id)) {
            Write-Host "⚠ Watcher-ът гръмна веднага!" -ForegroundColor Red
            Write-Host "Провери лог: $logFile" -ForegroundColor Yellow
            Write-Host "Стартирай ръчно за дебъг:" -ForegroundColor Yellow
            Write-Host "  powershell -NoProfile -ExecutionPolicy Bypass -File `"$ps1`"" -ForegroundColor Cyan
        } else {
            Write-Host "Watcher работи." -ForegroundColor Green
        }
    }
    "stop" {
        $st = Get-State
        if (-not $st -or -not (Test-Alive $st.pid)) {
            Write-Host "Не работи." -ForegroundColor Yellow
            return
        }
        "stop" | Out-File -Encoding utf8 $stopFile
        Write-Host "Изпратен stop маркер. Изчакване..."
        for ($i=0; $i -lt 15; $i++) {
            Start-Sleep -Seconds 1
            if (-not (Test-Alive $st.pid)) { Write-Host "Спрян." -ForegroundColor Green; return }
        }
        Write-Host "Не спря gracefully, kill-вам PID $($st.pid)..." -ForegroundColor Yellow
        Stop-Process -Id $st.pid -Force -ErrorAction SilentlyContinue
    }
    "status" {
        $st = Get-State
        if (-not $st) { Write-Host "Няма state. Watcher никога не е стартирал (или е гръмнал при старт)."; return }
        $alive = Test-Alive $st.pid
        Write-Host "=== Статус ==="
        Write-Host "PID:              $($st.pid)  (жив: $alive)"
        Write-Host "Състояние:        $($st.status)"
        Write-Host "Стартиран:        $($st.started)"
        Write-Host "Последна промяна: $($st.lastChange)"
        Write-Host "Последен commit:  $($st.lastCommit)"
        Write-Host "Repo:             $($st.repoPath)"
        Write-Host "Клон:             $($st.branch)"
    }
    "logs" {
        if ($Arg1 -match '^\d+$') { $Tail = [int]$Arg1 }
        if (-not (Test-Path $logFile)) { Write-Host "Няма лог."; return }
        Get-Content $logFile -Tail $Tail
    }
    "restart" {
        & $PSCommandPath stop
        Start-Sleep 2
        & $PSCommandPath start
    }
    default {
        Write-Host "Употреба: git-sync.ps1 <start|stop|status|logs|restart> [N]"
        Write-Host "Пример:   .\git-sync.ps1 logs 50"
    }
}
