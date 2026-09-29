param([string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference='Stop';$root=Join-Path $ProjectRoot '_crypto';$mf=Join-Path $root 'CRYPTO_MANIFEST.json'
if(-not(Test-Path $mf)){throw 'CRYPTO_MANIFEST.json missing. Run Import-Crypto.ps1 first.'}
$m=Get-Content -Raw $mf|ConvertFrom-Json;$bad=0
foreach($r in $m.files){$p=Join-Path $root $r.path;if(-not(Test-Path $p)){Write-Host "[MISSING] $($r.path)";$bad++;continue};$h=(Get-FileHash $p -Algorithm SHA256).Hash.ToLowerInvariant();if($h-ne$r.sha256){Write-Host "[MISMATCH] $($r.path)";$bad++}}
if($bad){throw "$bad crypto file(s) failed integrity verification"};Write-Host "[PASS] $($m.files.Count) crypto files verified"
