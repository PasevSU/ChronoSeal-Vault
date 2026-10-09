$ErrorActionPreference = 'Stop'
$AllowNetworkFallback = ($env:PASEVSU_ALLOW_VENDOR_DOWNLOAD -eq '1')
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $Root 'vendor_resolver.ps1')

$Scripts = Join-Path $Root 'scripts'
New-Item -ItemType Directory -Force -Path $Scripts | Out-Null
$RequiredOpenPgpVersion = '6.3.1'
$OpenPgpStamp = Join-Path $Scripts 'openpgp.version'
$OpenPgpTarget = Join-Path $Scripts 'openpgp.min.js'
$QrTarget = Join-Path $Scripts 'qrcode.min.js'
$QrProviderStamp = Join-Path $Scripts 'qrcode.provider'
$JsPdfTarget = Join-Path $Scripts 'jspdf.umd.min.js'
$JsPdfProviderStamp = Join-Path $Scripts 'jspdf.provider'
$JsPdfVersionStamp = Join-Path $Scripts 'jspdf.version'
$RequiredJsPdfVersion = '4.2.1'

$crypto = Resolve-PasevSUCryptoHome -ProjectRoot $Root
if ($crypto.Found) {
    $env:PASEVSU_CRYPTO_HOME = $crypto.Path
    Write-Host "[OK] _crypto resolved ($($crypto.Kind)): $($crypto.Path)"
} else {
    Write-Warning '_crypto was not found. Network fallback is disabled by default; set PASEVSU_ALLOW_VENDOR_DOWNLOAD=1 only for an explicit bootstrap.'
}

function Get-Dependency([string]$Name, [string[]]$Urls, [string]$Target, [int]$MinBytes, [string]$ProviderStamp = '') {
    $HashStamp = $Target + '.sha256'
    if ((Test-Path -LiteralPath $Target) -and (Test-Path -LiteralPath $HashStamp)) {
        $size = (Get-Item -LiteralPath $Target).Length
        $expected = (Get-Content -LiteralPath $HashStamp -Raw).Trim().ToLowerInvariant()
        $actual = Get-PasevSUFileSha256 -Path $Target
        if ($size -ge $MinBytes -and $expected -and $actual -eq $expected) { Write-Host "[OK] $Name already present and SHA-256 verified ($size bytes)"; return }
    }
    Remove-Item -LiteralPath $Target -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $HashStamp -Force -ErrorAction SilentlyContinue
    if (!$AllowNetworkFallback) { throw "$Name is not available from verified local _crypto. Network bootstrap is disabled. Set PASEVSU_ALLOW_VENDOR_DOWNLOAD=1 to opt in explicitly." }
    foreach ($url in $Urls) {
        try {
            Write-Host "[GET] $Name <- $url"
            Invoke-WebRequest -Uri $url -OutFile $Target -UseBasicParsing
            $size = (Get-Item -LiteralPath $Target).Length
            if ($size -lt $MinBytes) { throw "Downloaded file is unexpectedly small ($size bytes)." }
            $hash = Get-PasevSUFileSha256 -Path $Target
            Set-Content -LiteralPath $HashStamp -Value $hash -Encoding ASCII
            Write-PasevSUVendorAudit -ProjectRoot $Root -Record @{
                event='vendor-download'; name=$Name; provider='network-fallback'; source=$url; destination=$Target;
                destinationSha256After=$hash; bytes=$size; verified=$true
            }
            if ($ProviderStamp) { Set-Content -LiteralPath $ProviderStamp -Value 'network-fallback' -Encoding ASCII }
            Write-Host "[OK] $Name installed ($size bytes, SHA-256 $hash)"
            return
        } catch {
            Write-Warning "$Name download failed from $url : $($_.Exception.Message)"
            Remove-Item -LiteralPath $Target -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $HashStamp -Force -ErrorAction SilentlyContinue
        }
    }
    throw "Unable to install $Name from all configured mirrors."
}

# OpenPGP.js: local source is trusted only when it provides an already-built
# browser bundle AND package.json reports the exact pinned version. Source-tree
# presence alone never triggers a build or an unpinned upgrade.
$openPgpInstalled = $false
if ($crypto.Found) {
    $openRoot = Join-Path $crypto.Path 'openpgpjs'
    $pkg = Join-Path $openRoot 'package.json'
    $localVersion = $null
    if (Test-Path -LiteralPath $pkg -PathType Leaf) {
        try { $localVersion = (Get-Content -LiteralPath $pkg -Raw | ConvertFrom-Json).version } catch {}
    }
    $localBundle = Join-Path $openRoot 'dist\openpgp.min.js'
    if ($localVersion -eq $RequiredOpenPgpVersion -and (Test-Path -LiteralPath $localBundle -PathType Leaf)) {
        $openPgpInstalled = Copy-PasevSULocalVendor -ProjectRoot $Root -Name "OpenPGP.js $RequiredOpenPgpVersion" `
            -Source $localBundle -Destination $OpenPgpTarget -MinBytes 200000 -Provider '_crypto/openpgpjs'
        if ($openPgpInstalled) { Set-Content -LiteralPath $OpenPgpStamp -Value $RequiredOpenPgpVersion -Encoding ASCII }
    } elseif ($localVersion) {
        Write-Host "[INFO] _crypto/openpgpjs source version is $localVersion; pinned browser runtime remains $RequiredOpenPgpVersion."
    }
}

$installedStamp = if (Test-Path -LiteralPath $OpenPgpStamp) { (Get-Content -LiteralPath $OpenPgpStamp -Raw).Trim() } else { '' }
if (!$openPgpInstalled) {
    if ($installedStamp -ne $RequiredOpenPgpVersion) {
        Remove-Item -LiteralPath $OpenPgpTarget -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath ($OpenPgpTarget + '.sha256') -Force -ErrorAction SilentlyContinue
    }
    Get-Dependency "OpenPGP.js $RequiredOpenPgpVersion" @(
        "https://unpkg.com/openpgp@$RequiredOpenPgpVersion/dist/openpgp.min.js",
        "https://cdn.jsdelivr.net/npm/openpgp@$RequiredOpenPgpVersion/dist/openpgp.min.js"
    ) $OpenPgpTarget 200000
    Set-Content -LiteralPath $OpenPgpStamp -Value $RequiredOpenPgpVersion -Encoding ASCII
}

# QR provider: prefer the user's central _crypto/qrcodejs. QRCode.js and
# qrcode-generator expose different APIs; app.js v2.1.1 supports both.
$qrInstalled = $false
if ($crypto.Found) {
    $qrCandidates = @(
        (Join-Path $crypto.Path 'qrcodejs\qrcode.js'),
        (Join-Path $crypto.Path 'qrcodejs\qrcode.min.js')
    )
    foreach ($localQr in $qrCandidates) {
        if (Test-Path -LiteralPath $localQr -PathType Leaf) {
            $provider = if ((Split-Path -Leaf $localQr) -eq 'qrcode.js') { '_crypto/qrcodejs/qrcode.js' } else { '_crypto/qrcodejs/qrcode.min.js' }
            $qrInstalled = Copy-PasevSULocalVendor -ProjectRoot $Root -Name 'QRCode.js' -Source $localQr `
                -Destination $QrTarget -MinBytes 10000 -Provider $provider
            if ($qrInstalled) {
                Set-Content -LiteralPath $QrProviderStamp -Value ("qrcodejs-local:" + (Split-Path -Leaf $localQr)) -Encoding ASCII
                break
            }
        }
    }
}
if (!$qrInstalled) {
    Get-Dependency 'qrcode-generator 1.4.4' @(
        'https://cdnjs.cloudflare.com/ajax/libs/qrcode-generator/1.4.4/qrcode.min.js',
        'https://cdn.jsdelivr.net/npm/qrcode-generator@1.4.4/qrcode.min.js'
    ) $QrTarget 10000 $QrProviderStamp
    Set-Content -LiteralPath $QrProviderStamp -Value 'qrcode-generator-network' -Encoding ASCII
}



# jsPDF report provider: prefer the central _crypto/jsPDF UMD browser bundle.
# package.json is recorded for audit, but local copies are accepted by actual
# bundle presence/size rather than forcing a single source checkout version.
$jsPdfInstalled = $false
if ($crypto.Found) {
    $pdfRoot = Join-Path $crypto.Path 'jsPDF'
    $pdfPkg = Join-Path $pdfRoot 'package.json'
    $pdfVersion = $null
    if (Test-Path -LiteralPath $pdfPkg -PathType Leaf) {
        try { $pdfVersion = (Get-Content -LiteralPath $pdfPkg -Raw | ConvertFrom-Json).version } catch {}
    }
    $pdfCandidates = @(
        (Join-Path $pdfRoot 'dist\jspdf.umd.min.js'),
        (Join-Path $pdfRoot 'dist\jspdf.umd.js')
    )
    if ($pdfVersion -and $pdfVersion -ne $RequiredJsPdfVersion) {
        Write-Host "[INFO] _crypto/jsPDF source version is $pdfVersion; pinned runtime remains $RequiredJsPdfVersion."
        $pdfCandidates = @()
    }
    foreach ($localPdf in $pdfCandidates) {
        if (Test-Path -LiteralPath $localPdf -PathType Leaf) {
            $provider = '_crypto/jsPDF/dist/' + (Split-Path -Leaf $localPdf)
            $jsPdfInstalled = Copy-PasevSULocalVendor -ProjectRoot $Root -Name 'jsPDF report provider' `
                -Source $localPdf -Destination $JsPdfTarget -MinBytes 100000 -Provider $provider
            if ($jsPdfInstalled) {
                Set-Content -LiteralPath $JsPdfProviderStamp -Value ("jspdf-local:" + (Split-Path -Leaf $localPdf)) -Encoding ASCII
                $versionToWrite = if ($pdfVersion) { $pdfVersion } else { 'local-unknown' }
                Set-Content -LiteralPath $JsPdfVersionStamp -Value $versionToWrite -Encoding ASCII
                break
            }
        }
    }
}
if (!$jsPdfInstalled) {
    $installedPdfStamp = if (Test-Path -LiteralPath $JsPdfVersionStamp) { (Get-Content -LiteralPath $JsPdfVersionStamp -Raw).Trim() } else { '' }
    if ($installedPdfStamp -ne $RequiredJsPdfVersion) { Remove-Item -LiteralPath $JsPdfTarget -Force -ErrorAction SilentlyContinue }
    Get-Dependency "jsPDF $RequiredJsPdfVersion" @(
        "https://unpkg.com/jspdf@$RequiredJsPdfVersion/dist/jspdf.umd.min.js",
        "https://cdn.jsdelivr.net/npm/jspdf@$RequiredJsPdfVersion/dist/jspdf.umd.min.js"
    ) $JsPdfTarget 100000 $JsPdfProviderStamp
    Set-Content -LiteralPath $JsPdfProviderStamp -Value 'jspdf-network-fallback' -Encoding ASCII
    Set-Content -LiteralPath $JsPdfVersionStamp -Value $RequiredJsPdfVersion -Encoding ASCII
}

Write-Host 'Vendor dependencies are ready.'
