$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
if (!(Get-Command python -ErrorAction SilentlyContinue)) { throw 'Python is required for frontend-only mode.' }
Set-Location $Root
Write-Host 'Frontend-only mode: http://127.0.0.1:5173 (keyserver proxy may be unavailable)'
python -m http.server 5173 --bind 127.0.0.1
