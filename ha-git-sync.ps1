# ha-git-sync.ps1 - Наблюдение на промени и автоматично подаване към Git
# Работи в Windows PowerShell 5.1+ / PowerShell 7+

param(
    [string]$RepoPath = "\\PASEVCLAUD\HDD (at HDD)\PROJECT\_ChronoSeal-Vault",
    [string]$Branch   = "main",
    [int]$Debounce    = 30,     # секунди изчакване след последна промяна
    [int]$PollInterval = 5      # секунди между проверките (за мрежови дялове)
)

# Принудително задаване на UTF-8 за git
$env:GIT_AUTHOR_NAME     = "HA Auto-Sync"
$env:GIT_AUTHOR_EMAIL    = "ha-autosync@local"
$env:GIT_COMMITTER_NAME  = "HA Auto-Sync"
$env:GIT_COMMITTER_EMAIL = "ha-autosync@local"

Set-Location $RepoPath

if (-not (Test-Path ".git")) {
    Write-Error "Грешка: $RepoPath не е Git хранилище"
    exit 1
}

Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Стартиране на наблюдението на $RepoPath"
Write-Host "  Branch: $Branch | Debounce: ${Debounce}s | Poll: ${PollInterval}s"

# Снимка на текущото състояние на файловете
function Get-RepoSnapshot {
    $files = Get-ChildItem -Path $RepoPath -Recurse -File -Force `
        -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\\.git\\' } |
        ForEach-Object {
            [PSCustomObject]@{
                Path     = $_.FullName
                LastWrite = $_.LastWriteTimeUtc.Ticks
                Size     = $_.Length
            }
        }
    return $files
}

$lastSnapshot = Get-RepoSnapshot
$lastChangeTime = Get-Date

while ($true) {
    Start-Sleep -Seconds $PollInterval
    $currentSnapshot = Get-RepoSnapshot

    # Сравнение на снимките (откриване на нови/променени/изтрити файлове)
    $diff = Compare-Object -ReferenceObject $lastSnapshot -DifferenceObject $currentSnapshot `
        -Property Path, LastWrite, Size -PassThru

    if ($diff) {
        $lastChangeTime = Get-Date
        $lastSnapshot = $currentSnapshot
        $changedCount = ($diff | Measure-Object).Count
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Открити $changedCount промени, изчакване на спокойствие..."
        continue
    }

    # Проверка дали е изтекъл debounce периодът
    $elapsed = (Get-Date) - $lastChangeTime
    if ($elapsed.TotalSeconds -lt $Debounce) {
        continue
    }

    # Проверка дали има какво да се подаде
    Set-Location $RepoPath
    $status = git status --porcelain
    if (-not $status) {
        continue   # Няма промени за подаване
    }

    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Подаване на промените..."
    git add -A
    $commitMsg = "auto-sync: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    git commit -m $commitMsg | Out-Null

    if ($LASTEXITCODE -eq 0) {
        git push origin $Branch 2>&1 | ForEach-Object {
            Write-Host "  $_"
        }
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Подаването е завършено"
    }

    # Нулиране на debounce таймера
    $lastChangeTime = Get-Date
}
