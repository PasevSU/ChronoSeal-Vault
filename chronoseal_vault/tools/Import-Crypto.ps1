param(
  [Parameter(Mandatory=$true)][string]$Source,
  [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)
$ErrorActionPreference='Stop'
$src=(Resolve-Path $Source).Path
$dst=Join-Path $ProjectRoot '_crypto'
if(-not (Test-Path $dst)){New-Item -ItemType Directory -Path $dst|Out-Null}
$wanted=@('javascript-opentimestamps','typescript-opentimestamps','java-opentimestamps','openpgpjs','qrcodejs','jsencrypt','trust')
foreach($name in $wanted){$s=Join-Path $src $name;if(Test-Path $s){$d=Join-Path $dst $name;Write-Host "[COPY] $name";if(Test-Path $d){Remove-Item -Recurse -Force $d};Copy-Item -Recurse -Force $s $d}}
$files=Get-ChildItem $dst -Recurse -File | Sort-Object FullName
$records=@();foreach($f in $files){$records += [ordered]@{path=$f.FullName.Substring($dst.Length+1).Replace('\\','/');bytes=$f.Length;sha256=(Get-FileHash $f.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}}
$manifest=[ordered]@{schema='pasevsu-crypto-manifest/v1';created_utc=(Get-Date).ToUniversalTime().ToString('o');source=$src;files=$records}
$manifest|ConvertTo-Json -Depth 6|Set-Content -Encoding UTF8 (Join-Path $dst 'CRYPTO_MANIFEST.json')
Write-Host "[OK] Imported $($records.Count) files; manifest: _crypto/CRYPTO_MANIFEST.json"
