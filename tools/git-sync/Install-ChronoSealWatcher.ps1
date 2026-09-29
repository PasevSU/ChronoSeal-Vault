$Watcher = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot 'Watch-ChronoSealRepo.ps1')
)

if ($Watcher.StartsWith(
    'Microsoft.PowerShell.Core\FileSystem::',
    [StringComparison]::OrdinalIgnoreCase
)) {
    $Watcher = $Watcher.Substring(
        'Microsoft.PowerShell.Core\FileSystem::'.Length
    )
}