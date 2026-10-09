$ErrorActionPreference='Stop'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $Root 'vendor_resolver.ps1')
$crypto = Resolve-PasevSUCryptoHome -ProjectRoot $Root
if (!$crypto.Found) { throw '_crypto not found' }
Write-Host "_crypto: $($crypto.Path) [$($crypto.Kind)]"
$checks = @(
  @{Name='OpenPGP.js'; Source=(Join-Path $crypto.Path 'openpgpjs\dist\openpgp.min.js'); Runtime=(Join-Path $Root 'scripts\openpgp.min.js')},
  @{Name='QRCode.js'; Source=(Join-Path $crypto.Path 'qrcodejs\qrcode.js'); Runtime=(Join-Path $Root 'scripts\qrcode.min.js')},
  @{Name='jsPDF'; Source=(Join-Path $crypto.Path 'jsPDF\dist\jspdf.umd.min.js'); Runtime=(Join-Path $Root 'scripts\jspdf.umd.min.js')}
)
foreach($c in $checks){
  if(!(Test-Path -LiteralPath $c.Source -PathType Leaf)){ Write-Warning "$($c.Name) source missing: $($c.Source)"; continue }
  if(!(Test-Path -LiteralPath $c.Runtime -PathType Leaf)){ throw "$($c.Name) runtime missing: $($c.Runtime)" }
  $sh=Get-PasevSUFileSha256 $c.Source; $rh=Get-PasevSUFileSha256 $c.Runtime
  $stamp=$c.Runtime+'.sha256'; if(!(Test-Path -LiteralPath $stamp)){ throw "$($c.Name) SHA-256 sidecar missing" }
  $pinned=(Get-Content -LiteralPath $stamp -Raw).Trim().ToLowerInvariant()
  if($sh -ne $rh -or $rh -ne $pinned){ throw "$($c.Name) hash mismatch: source=$sh runtime=$rh pinned=$pinned" }
  Write-Host "$($c.Name): SHA-256 VERIFIED $rh"
}
