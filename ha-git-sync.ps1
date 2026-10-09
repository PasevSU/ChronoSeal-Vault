param(
    [string]$RepoPath  = "\\PASEVCLAUD\HDD (at HDD)\PROJECT\_ChronoSeal-Vault",
    [string]$Branch    = "main",
    [int]$Debounce     = 30,
    [int]$PollInterval = 5
)

if (-not (Test-Path $RepoPath)) { Write-Error "Пътят не съществува: $RepoPath"; exit 1 }
Set-Location $RepoPath
if (-not (Test-Path ".git"))    { Write-Error "Не е Git репозиторий";      exit 1 }

Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Наблюдение над $RepoPath..."

function Get-Snapshot {
    Get-ChildItem $RepoPath -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\\.git\\' } |
        ForEach-Object {
            "{0}|{1}|{2}" -f $_.FullName, $_.LastWriteTimeUtc.Ticks, $_.Length
        }
}

$lastSnap   = Get-Snapshot
$lastChange = Get-Date

while ($true) {
    Start-Sleep -Seconds $PollInterval
    $currSnap = Get-Snapshot

    $same = ($lastSnap.Count -eq $currSnap.Count) -and
            (-not (Compare-Object $lastSnap $currSnap))

    if (-not $same) {
        $lastSnap   = $currSnap
        $lastChange = Get-Date
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Промяна, изчакване..."
        continue
    }

    if (((Get-Date) - $lastChange).TotalSeconds -lt $Debounce) { continue }

    Set-Location $RepoPath
    if (-not (git status --porcelain)) { $lastChange = Get-Date; continue }

    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Commit..."
    git add -A
    git commit -m "auto-sync: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-Null
    if ($LASTEXITCODE -eq 0) {
        git push origin $Branch 2>&1 | ForEach-Object { Write-Host "  $_" }
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Push готов"
    }
    $lastChange = Get-Date
}
