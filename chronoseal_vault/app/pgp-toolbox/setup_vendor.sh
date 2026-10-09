#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$ROOT/scripts"; LOGS="$ROOT/logs"; mkdir -p "$SCRIPTS" "$LOGS"
OPENPGP_VERSION=6.3.1
JSPDF_VERSION=4.2.1
ALLOW_NETWORK_FALLBACK="${PASEVSU_ALLOW_VENDOR_DOWNLOAD:-0}"

sha256_file(){ if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'; else shasum -a 256 "$1" | awk '{print $1}'; fi; }
verify_existing(){ local dst="$1" min="$2"; [[ -f "$dst" && -f "$dst.sha256" ]] || return 1; (( $(wc -c < "$dst") >= min )) || return 1; [[ "$(sha256_file "$dst")" == "$(tr -d '\r\n ' < "$dst.sha256")" ]]; }
CRYPTO="${PASEVSU_CRYPTO_HOME:-}"
if [[ -z "$CRYPTO" || ! -d "$CRYPTO" ]]; then
  [[ -d "$(dirname "$ROOT")/_crypto" ]] && CRYPTO="$(dirname "$ROOT")/_crypto" || true
fi
if [[ -z "$CRYPTO" || ! -d "$CRYPTO" ]]; then [[ -d "$ROOT/_crypto" ]] && CRYPTO="$ROOT/_crypto" || true; fi
[[ -n "$CRYPTO" && -d "$CRYPTO" ]] && echo "[OK] _crypto: $CRYPTO" || echo "[WARN] _crypto not found"

copy_local(){ local name="$1" src="$2" dst="$3" min="$4" provider="$5"; [[ -f "$src" ]] || return 1; local size; size=$(wc -c < "$src"); (( size >= min )) || return 1; local sh dh=""; sh=$(sha256_file "$src"); [[ -f "$dst" ]] && dh=$(sha256_file "$dst"); [[ "$sh" == "$dh" ]] || cp -f "$src" "$dst"; printf '%s\n' "$sh" > "$dst.sha256"; printf '{"event":"vendor-sync","name":"%s","provider":"%s","sourceSha256":"%s","bytes":%s,"verified":true}\n' "$name" "$provider" "$sh" "$size" >> "$LOGS/vendor-resolver.jsonl"; echo "[OK] $name from $provider ($size bytes, SHA-256 $sh)"; }

download(){ local name="$1" dst="$2" min="$3"; shift 3; verify_existing "$dst" "$min" && { echo "[OK] $name already present and SHA-256 verified"; return; }; rm -f "$dst" "$dst.sha256"; [[ "$ALLOW_NETWORK_FALLBACK" == "1" ]] || { echo "$name is unavailable from verified local _crypto. Set PASEVSU_ALLOW_VENDOR_DOWNLOAD=1 for explicit network bootstrap." >&2; exit 1; }; for url in "$@"; do echo "[GET] $name <- $url"; if curl -fL --connect-timeout 10 --max-time 60 "$url" -o "$dst"; then local size; size=$(wc -c < "$dst"); if (( size >= min )); then sha256_file "$dst" > "$dst.sha256"; echo "[OK] $name installed ($size bytes; SHA-256 pinned locally)"; return; fi; fi; rm -f "$dst"; done; echo "Unable to install $name" >&2; exit 1; }

OPEN_OK=0
if [[ -n "$CRYPTO" && -f "$CRYPTO/openpgpjs/package.json" && -f "$CRYPTO/openpgpjs/dist/openpgp.min.js" ]]; then
  VER=$(node -e "console.log(require(process.argv[1]).version||'')" "$CRYPTO/openpgpjs/package.json" 2>/dev/null || true)
  if [[ "$VER" == "$OPENPGP_VERSION" ]]; then copy_local "OpenPGP.js $OPENPGP_VERSION" "$CRYPTO/openpgpjs/dist/openpgp.min.js" "$SCRIPTS/openpgp.min.js" 200000 "_crypto/openpgpjs" && OPEN_OK=1; fi
fi
STAMP=""; [[ -f "$SCRIPTS/openpgp.version" ]] && STAMP=$(tr -d '\r\n ' < "$SCRIPTS/openpgp.version")
if [[ $OPEN_OK -eq 0 ]]; then
  [[ "$STAMP" == "$OPENPGP_VERSION" ]] || rm -f "$SCRIPTS/openpgp.min.js" "$SCRIPTS/openpgp.min.js.sha256"
  download "OpenPGP.js $OPENPGP_VERSION" "$SCRIPTS/openpgp.min.js" 200000 "https://unpkg.com/openpgp@$OPENPGP_VERSION/dist/openpgp.min.js" "https://cdn.jsdelivr.net/npm/openpgp@$OPENPGP_VERSION/dist/openpgp.min.js"
fi
printf '%s\n' "$OPENPGP_VERSION" > "$SCRIPTS/openpgp.version"

QR_OK=0
if [[ -n "$CRYPTO" ]]; then
  if copy_local "QRCode.js" "$CRYPTO/qrcodejs/qrcode.js" "$SCRIPTS/qrcode.min.js" 10000 "_crypto/qrcodejs/qrcode.js"; then QR_OK=1; echo 'qrcodejs-local:qrcode.js' > "$SCRIPTS/qrcode.provider";
  elif copy_local "QRCode.js" "$CRYPTO/qrcodejs/qrcode.min.js" "$SCRIPTS/qrcode.min.js" 10000 "_crypto/qrcodejs/qrcode.min.js"; then QR_OK=1; echo 'qrcodejs-local:qrcode.min.js' > "$SCRIPTS/qrcode.provider"; fi
fi
if [[ $QR_OK -eq 1 ]]; then :; else
  download "qrcode-generator 1.4.4" "$SCRIPTS/qrcode.min.js" 10000 "https://cdnjs.cloudflare.com/ajax/libs/qrcode-generator/1.4.4/qrcode.min.js" "https://cdn.jsdelivr.net/npm/qrcode-generator@1.4.4/qrcode.min.js"
  echo qrcode-generator-network > "$SCRIPTS/qrcode.provider"
fi


PDF_OK=0
if [[ -n "$CRYPTO" ]]; then
  PDF_VER=""
  [[ -f "$CRYPTO/jsPDF/package.json" ]] && PDF_VER=$(node -e "console.log(require(process.argv[1]).version||'')" "$CRYPTO/jsPDF/package.json" 2>/dev/null || true)
  if [[ "$PDF_VER" == "$JSPDF_VERSION" ]] && copy_local "jsPDF report provider" "$CRYPTO/jsPDF/dist/jspdf.umd.min.js" "$SCRIPTS/jspdf.umd.min.js" 100000 "_crypto/jsPDF/dist/jspdf.umd.min.js"; then PDF_OK=1; echo 'jspdf-local:jspdf.umd.min.js' > "$SCRIPTS/jspdf.provider";
  elif [[ "$PDF_VER" == "$JSPDF_VERSION" ]] && copy_local "jsPDF report provider" "$CRYPTO/jsPDF/dist/jspdf.umd.js" "$SCRIPTS/jspdf.umd.min.js" 100000 "_crypto/jsPDF/dist/jspdf.umd.js"; then PDF_OK=1; echo 'jspdf-local:jspdf.umd.js' > "$SCRIPTS/jspdf.provider"; fi
  [[ $PDF_OK -eq 1 ]] && printf '%s\n' "${PDF_VER:-local-unknown}" > "$SCRIPTS/jspdf.version"
fi
if [[ $PDF_OK -eq 0 ]]; then
  PDF_STAMP=""; [[ -f "$SCRIPTS/jspdf.version" ]] && PDF_STAMP=$(tr -d '\r\n ' < "$SCRIPTS/jspdf.version")
  [[ "$PDF_STAMP" == "$JSPDF_VERSION" ]] || rm -f "$SCRIPTS/jspdf.umd.min.js"
  download "jsPDF $JSPDF_VERSION" "$SCRIPTS/jspdf.umd.min.js" 100000 "https://unpkg.com/jspdf@$JSPDF_VERSION/dist/jspdf.umd.min.js" "https://cdn.jsdelivr.net/npm/jspdf@$JSPDF_VERSION/dist/jspdf.umd.min.js"
  echo jspdf-network-fallback > "$SCRIPTS/jspdf.provider"; printf '%s\n' "$JSPDF_VERSION" > "$SCRIPTS/jspdf.version"
fi

echo 'Vendor dependencies are ready.'
