# PasevSU PGP Toolbox v2.1.1 — Test Report

Build/audit date: 2026-09-28.

## Executed and passed

- `python verify_project.py`: 258 unique HTML IDs, 196/196 bound controls, 21 top-level tools, BG+DE, JS syntax, Bash syntax and full security/release contract.
- `tests/test_advanced_core_static.mjs`: Advanced OpenPGP Core policy/API markers.
- `tests/test_bootstrap_static.mjs`: external canonical-origin bootstrap, exact v2.1.1 health contract, no npm dependency step, network-only Service Worker.
- `tests/test_policy_engine_static.mjs`: enforced message/file encryption policy gates and runtime-integrity gate.
- `tests/test_report_engine_static.mjs`: report privacy/integrity contract.
- `tests/test_report_runtime.mjs`: canonical SHA-256/SHA-512, private-material exclusion and stable PDF/JSON snapshot reuse until inputs change.
- `tests/test_runtime_capabilities_static.mjs`: exact PQ classifier and `_crypto` capability privacy.
- `tests/test_security_hardening.mjs`: XSS/private-manifest/revocation/certification/Fortress/server assertions.
- `tests/test_vendor_resolver_static.mjs`: central `_crypto`, exact versions and SHA-256 sidecar contract.
- `tests/test_vendor_resolver_runtime.mjs`: simulated sibling `_crypto` local sync, runtime-file tamper repair and fail-closed version/hash mismatch with network bootstrap disabled.
- `tests/test_wkd_utils.mjs`: WKD z-base-32 and URL construction.
- `tests/test_fortress_v2_static.mjs`: in-memory Fortress V2 outer-header binding, V1 decrypt compatibility and V2 write path.
- `tests/test_fortress_v3.mjs`: authenticated inner metadata manifest round-trip and tamper rejection; HTML escaping helper payload test.
- `tests/test_stream_chain.mjs`: chunk-boundary-independent SHA-512 chain, 3 variants, digest `8492c6f30018fde96a9048e8bae2922e92ea3aea892fd8899c78a7588e2c3224bc80c68fa4cb429214fc1c590398e99de97930a249984e18313ea7adef79a970`.
- `tests/test_server_runtime.mjs`: real Node server startup, v2.1.1 health, CSP, bad Host/Origin rejection, decoded-path traversal rejection, malformed-encoding rejection, vendor fail-closed response, capability path privacy and 256 KiB request limit.
- `tests/test_server_vendor_integrity.mjs`: real server with valid vendor fixtures reports `vendorReady=true`, serves verified bundles, then detects runtime tampering and returns HTTP 503.
- Responsive DOM contract: 21 cards, 258 unique IDs, 196/196 controls bound, one-open accordion/BG-DE/responsive CSS markers verified statically. The v2.1.1 Chromium re-run was attempted but the container Chromium process stalled before DOM output; no new live layout PASS is claimed for v2.1.1.
- All non-vendor JS/MJS files passed `node --check`.
- `setup_vendor.sh` passed `bash -n`.
- `verify_project.py` passed Python bytecode compilation.

## Environment-limited tests

The build environment intentionally does not contain the user's sibling `PROJECT/_crypto` runtime files and cannot download npm/CDN binaries directly. Therefore the actual `scripts/openpgp.min.js`, `scripts/qrcode.min.js` and `scripts/jspdf.umd.min.js` are not embedded and the two target browser self-tests are included but not claimed as executed:

- `tests/runtime_openpgp_v21.html` / `.js`
- `tests/runtime_report_v21.html` / `.js`

After `setup_vendor.ps1` synchronizes the real pinned runtime on the Windows target, these tests exercise OpenPGP key/subkey validation, exact-email encrypt/decrypt/signature verification, session-key extraction, subkey/User-ID revocation, generic certification, revocation-certificate apply, Argon2 password encryption and exact PQ classification, plus jsPDF report generation.

Windows Script Host and PowerShell are not available in this Linux build environment. VBS/PowerShell launcher logic was therefore audited statically; shell-side vendor resolution and the actual Node server were executed separately. The prior `$LASTEXITCODE` misuse after invoking `setup_vendor.ps1` was corrected to PowerShell-native success semantics.

Headless Chromium in this environment does not provide a reliable v2.1.1 browser run: direct loopback/file navigation is policy-restricted and the self-contained re-run stalled before DOM output. Therefore canonical redirect/live-loopback navigation and the v2.1.1 responsive layout are not claimed as live PASS. Bootstrap, DOM binding, accordion/i18n markers and responsive CSS are covered statically; the earlier v2.1.0 layout harness results are not reused as a v2.1.1 runtime claim.

## Clean-release verification

The final ZIP was extracted into a new directory; `verify_project.py`, every `tests/test_*.mjs` Node regression, and an independent 58-file manifest SHA-256/size verification all passed from the clean extraction. ZIP integrity also passed.

## Release conclusion

No known CRITICAL/HIGH defect from the v2.0.1 audit or the subsequent clean v2.1.0 precision audit remains open in the v2.1.1 code path. Explicit compatibility boundaries remain documented: legacy Fortress Streaming V2 outer metadata is not authenticated and requires a warning to decrypt; OpenPGP.js 6.3.2 is not adopted until separately reviewed; Windows launcher and real vendor-backed browser self-tests must still be executed on the target Windows installation.
