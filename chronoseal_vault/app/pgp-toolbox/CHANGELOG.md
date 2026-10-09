# Changelog

## v2.1.1 — Final precision hardening

- Fixed decoded static-path allowlisting so encoded slash/dot traversal cannot escape `style/`, `scripts/`, `icons/`, or `tests/`.
- Added server-side SHA-256 enforcement for OpenPGP.js, QR and jsPDF runtime bundles; tampered vendor files now return HTTP 503 and `/api/health` reports `vendorReady`.
- Added per-project launcher instance IDs so a same-version PasevSU server from another project copy is never silently reused or terminated.
- Fixed asynchronous primary/subkey expiration reporting in Key Manifest and Key Inspector.
- Keyserver refresh now merges updates into private-key containers when present, preserving fetched revocations/certifications across later lifecycle operations.
- Removed persistent passphrase removal; private keys remain protected and passphrase rotation requires at least 16 characters.
- Added non-streaming Fortress V2 with encrypted inner binding of the complete outer metadata; legacy Fortress V1 remains decrypt-only compatible.
- PDF/JSON report exports now share one stable canonical snapshot/Report-ID until the snapshot is explicitly reset or report inputs change.
- Clarified that PDF Page-ID is a derived identifier from the canonical report hash and page ordinal, not a hash of rendered PDF page bytes.
- Extended SSRF address filtering and final runtime regression coverage.


## 2.1.0 — Security & Correctness Hardening

- Replaced Express/CORS/Helmet backend with a dependency-free Node.js loopback server.
- Added strict Host/Origin enforcement, CSP and hardened security headers.
- Moved canonical-origin bootstrap to external `scripts/bootstrap.js`; removed inline handlers.
- Removed Service Worker application/vendor caching; network-only with old-cache cleanup.
- Escaped untrusted OpenPGP/network/file metadata before HTML rendering.
- Public manifest export never includes armored private-key material.
- Fixed revocation certificate workflow and wired reason/text to the OpenPGP operation.
- Removed unsupported certification-level/expiration/notation controls; generic certification is verified before export.
- Fixed PQ capability detection so classical DSA/ECDSA/legacy EdDSA cannot trigger PQ status.
- Enforced Policy Engine gates for message and batch-file encryption.
- Added Fortress Streaming V3 authenticated inner metadata manifest; V2 is legacy-read with warning.
- Added SHA-256 runtime vendor sidecars and disabled network bootstrap by default.
- Made IndexedDB whole-store writes atomic.
- Blocked unprotected private-key import; new/change passphrases require >=16 characters and Argon2 S2K.
- Upgraded encrypted backup v2 to OpenPGP Argon2id + AES-256 + AEAD GCM; v1 restore retained.
- Fixed binary/armored batch decryption detection and pre-loop error recovery.
- Web of Trust edges now require cryptographic certification verification.
- Removed unverified PGP/MIME feature claim and non-PGP OpenTimestamps capability exposure.
- Report UI is German-only until a verified Unicode font provider exists; dead Unicode checkbox removed.


## 2.0.1
- Hardened one-click boot: the launcher starts the local Node server automatically and opens the browser only after an exact-version health check passes.
- Added safe stale-version replacement for managed PasevSU server processes; unrelated services on port 3000 are never terminated.
- Replaced the file-only redirect with a canonical-origin guard: any non-`http://127.0.0.1:3000` load of `index.html` redirects to the local server.
- Added `Cache-Control: no-store` to `/` and `/api/health` to avoid stale boot/version state.
- Removed the obsolete `start_frontend_only.ps1` path; v2.0.1 has one canonical application origin only.
- Service Worker navigation is network-only and the app shell is no longer precached, preventing a cached UI from masquerading as a healthy app while the backend is down.
- Added bootstrap regression tests.


## 2.0.0 — Provider/Policy + Technical Report Engine

- Added central `_crypto/jsPDF` vendor resolution with SHA-256 verified runtime synchronization and provider/version stamps.
- Added `Provider & Policy Negotiation` with RFC 9580 strict, modern-compatible, legacy interoperability, forensic read-only and RFC 9980 PQ/T-gated profiles.
- Added explicit no-silent-downgrade decisions (`READY`, `READ_ONLY`, `BLOCKED`).
- Added Technical PDF Report Engine using jsPDF UMD, A4 layout, canonical SHA-256/SHA-512, Report-ID, 128-hex Page-IDs and QR report identity.
- Report inventory exposes public metadata only; private key material is excluded from the report cross-module API.
- Fixed Advanced OpenPGP report export: it now emits one valid `pasevsu-advanced-report/2.0` JSON object instead of concatenated JSON documents.
- Runtime Capability Matrix now reports jsPDF source/runtime/provider/hash status.
- Bulgarian PDF generation is blocked until a verified Unicode font provider is configured; no fake/transliterated evidence output.
- Added policy/report static contracts and sibling `_crypto/jsPDF` integration test.

## 1.9.1 — Central `_crypto` Vendor Resolver

- Corrected `_crypto` topology for the deployed layout: `PROJECT/_WEB_pgp` and sibling `PROJECT/_crypto`.
- Added shared `vendor_resolver.ps1`; resolution order is explicit environment override → sibling `_crypto` → project-local `_crypto` → legacy shortcut.
- Removed the placeholder `_crypto` directory from the release package so it cannot mask a missing central backend.
- Added SHA-256 verified local vendor synchronization and JSONL audit log at `logs/vendor-resolver.jsonl`.
- Prefer `_crypto/qrcodejs/qrcode.js`, with `qrcode.min.js` as local fallback; retain qrcode-generator 1.4.4 only as network fallback.
- Added dual QR runtime compatibility for `QRCode.js` (`new QRCode`) and `qrcode-generator` (`qrcode(...)`).
- Local OpenPGP.js is accepted only when a prebuilt browser bundle exists and `package.json` exactly matches pinned version 6.3.1; source presence never triggers an implicit upgrade/build.
- Capability API now reports QR provider, bundle SHA-256, local-source SHA-256 and whether both hashes match.
- Service-worker cache bumped to `pasevsu-pgp-v12`; local server metadata bumped to 1.9.1.

## 1.9.0 — `_crypto` Capability Negotiation + WKD

- Promoted project-local `_crypto/` to an explicit internal backend boundary; it is never served as static browser content.
- Launcher now detects `<project>/_crypto` and can resolve `_crypto.lnk`, then passes the backend through `PASEVSU_CRYPTO_HOME`.
- Added `/api/crypto-capabilities` and a 20th top-level UI section showing source presence, browser/runtime exposure and verification state separately.
- Detects local OpenPGP.js source version, PQ source files (`ML-KEM`/`ML-DSA`), browser bundle, Java `OtsCli.jar`, Java runtime, TypeScript OpenTimestamps, Web Streams and File System Access.
- PQ/RFC 9980 is deliberately not enabled merely because source files are present.
- Added server-side WKD discovery before VKS fallback, with advanced/direct WKD URL construction and binary key transport.
- Added a regression test for the canonical WKD hash/URL example (`Joe.Doe@Example.ORG`).
- Exact-email browser discovery now accepts binary WKD certificates and still enforces exact User-ID validation, usable encryption key, validity and fingerprint confirmation.
- Discovered keys cannot be saved until fingerprint confirmation is checked.
- Added browser security-baseline reporting for OpenPGP.js >= 6.1.1, the patched baseline for CVE-2025-47934.
- Service-worker cache bumped to `pasevsu-pgp-v11`; local server metadata bumped to 1.9.0.

## 1.8.0 — Advanced OpenPGP Core

- Added a dedicated Advanced OpenPGP Core as the 19th top-level tool.
- Added per-operation Strict Security Policy: minimum RSA size, RFC 9580 grammar enforcement, SHA-1/MD5 rejection, decompression limit, authenticated-only decryption and optional constant-time RSA session-key decryption.
- Added Deep Key Health with `verifyPrimaryKey`, `verifyAllUsers`, per-subkey `verify`, historical validation date and optional `PrivateKey.validate`.
- Added Identity Lifecycle Manager: add signing/encryption subkeys to an existing primary identity, revoke one subkey, revoke one User ID, or revoke the complete identity.
- Lifecycle writes preserve the primary fingerprint, re-protect encrypted private keys and record local lifecycle metadata.
- Extended normal message encryption with optional sign-before-encrypt, exact signing subkey selection, signed Case/Evidence notations, wildcard recipient Key IDs and Strict Policy.
- Extended message decryption with expected sender key, `expectSigned`, historical signature-validation date and signature audit.
- Added Session Key & Recipient Inspector using `getEncryptionKeyIDs`, `getSigningKeyIDs` and `decryptSessionKeys`; raw session-key bytes remain hidden by default.
- Added ASCII Armor & Message Inspector using `unarmor()`, binary SHA-256/SHA-512 hashing and message recipient/signing Key-ID extraction.
- Added explicit OpenPGP compression selection (automatic, none, ZIP, ZLIB) to message encryption.
- Fixed the existing Session Keys algorithm selector: AES-128/192/256 now actually controls `generateSessionKey()` instead of being read by the UI and ignored.
- Added BG/DE localization and explanatory guide for the complete Advanced Core.
- Added `tests/test_advanced_core_static.mjs` and target-browser `tests/runtime_openpgp_v18.html`.
- Service-worker cache bumped to `pasevsu-pgp-v10`; local server metadata bumped to 1.8.0.

## 1.7.0 — Exact Email Recipient Encryption

- Added exact recipient email mode to Encrypt Message; it is now the default recipient workflow.
- Added exact User ID validation, valid encryption-subkey selection, fingerprint/Key-ID display and mandatory fingerprint confirmation.
- Added local exact-email key discovery and verified exact-email fallback through keys.openpgp.org VKS.
- Added `/api/discover-email` with input validation, response size limits, timeout handling and a 15-minute public-key cache.
- Encryption binds to the exact recipient identity via `encryptionUserIDs` and to the validated encryption subkey via `encryptionKeyIDs`.
- Added optional saving of discovered public keys into the local PasevSU key store.
- Preserved the existing stored-key multi-recipient mode.
- Added complete Bulgarian/German UI text and updated the Encrypt Message guide.
- Service-worker cache bumped to `pasevsu-pgp-v9`; local server metadata bumped to 1.7.0.

## 1.6.0 — Fortress Streaming V2

- Added direct-to-disk Web Streams encryption/decryption for large files.
- Preserves the full four-layer Fortress chain: Brainpool P-512 → NIST P-521 → RSA-8192 → RSA-4096.
- MAX+ streaming keeps the independent Argon2id + AES-256-GCM password layer.
- Added `.pasevsu-fortress-v2` binary container with versioned JSON header and payload offset.
- Added `SHA-512-CHAIN-V1`: fixed 1 MiB block hashing, independent of browser stream chunk boundaries.
- Streaming decryption verifies chain digest and original byte length before committing the output; failed verification truncates the output.
- Existing V1 in-memory Fortress format remains supported for text and smaller files.
- Added BG/DE strings, progress/status UI and direct-to-disk buttons.
- Service-worker cache bumped to `pasevsu-pgp-v8`; local server metadata bumped to 1.6.0.

## 1.5.0 — PasevSU Fortress MAX multi-layer encryption

- Added a dedicated Fortress MAX engine with four mandatory nested asymmetric layers: Brainpool P-512 ECDH, NIST P-521 ECDH, RSA-8192 and RSA-4096.
- Every asymmetric layer creates a fresh OpenPGP session key; ciphertext from each layer becomes the input of the next.
- Added MAX+ profile with an independent Argon2id password layer (3 passes, parallelism 4, 128 MiB memory target) outside the four asymmetric layers.
- Added AES-256 + RFC 9580 AEAD/GCM configuration for Fortress operations.
- Added an encrypted inner envelope with SHA-512 digest verification after complete decryption.
- Added `.pasevsu-fortress` binary container and armored PasevSU Fortress text package.
- Added BG/DE UI text and four-part guide for the Fortress module.
- Universal MAX key generation now advertises AES-256/AEAD preferences and protects secret-key material with Argon2id.
- Browser OpenPGP.js pin raised to 6.3.1; launcher checks a version stamp so an older local vendor bundle is refreshed.
- Browser Fortress mode has a 128 MiB per-item safety limit because nested in-memory encryption multiplies memory use.
- Top-level tools increased from 17 to 18; accordion single-open behavior remains in force.
- Service-worker cache bumped to `pasevsu-pgp-v7`; server metadata bumped to 1.5.0.

## 1.4.0 — PasevSU Universal MAX key suite

- Added `PasevSU Universal MAX` as the default high-assurance key-generation profile.
- One primary Brainpool P-512 identity root plus eight role-specific subkeys.
- Added Brainpool P-512, NIST P-521, RSA-8192 and RSA-4096 signing/encryption roles.
- Universal MAX requires a passphrase of at least 16 characters.
- Added explicit warning that multiple subkeys are capabilities/alternatives and are not automatically serial nested encryption.
- Suite metadata is stored under `meta.pasevSUSuite` and the generated revocation certificate is retained with the key record.
- Updated BG/DE guide and algorithm labels.
- Server/version metadata bumped to 1.4.0 and service-worker cache to `pasevsu-pgp-v6`.

## 1.3.0 — High-strength key generation

- Added RSA-3072, RSA-8192 and RSA-16384 generation profiles.
- Added explicit ECC P-256, P-384, P-521 and Brainpool P-512 profiles.
- Added live BG/DE security profile guidance with approximate classical strength class, generation cost and interoperability.
- RSA-16384 is marked Extreme/Expert and requires an explicit confirmation before generation.
- Very-high/extreme profiles warn before creating an unprotected private key without a passphrase.
- Key-generation guide expanded in Bulgarian and German.
- Service-worker cache bumped to `pasevsu-pgp-v5`.

## 1.0.0 — 2026-09-28

- Consolidated the supplied PGPBox material into a real project tree.
- Preserved all 17 UI modules and the combined `app.js` logic.
- Removed the runtime Tailwind dependency and added the required local utility CSS subset.
- Added a local SVG application icon and updated the PWA manifest.
- Improved service-worker precaching so a single failed asset does not cancel the entire install cache.
- Changed the Node server to serve both the frontend and the keyserver proxy on one origin.
- Added automatic proxy discovery for same-origin and localhost development.
- Hardened CORS allowlist parsing and added Node engine metadata.
- Added Windows/Linux vendor setup scripts and one-command Windows launchers.
- Added architecture and security documentation.

## 1.0.1 — 2026-09-28

- Fixed Windows UNC startup failure when the project is stored on a network share.
- Removed `npm start` from the PowerShell launcher because npm delegates package scripts to `cmd.exe`, which cannot use a UNC path as its current directory.
- `start.ps1` now launches Node directly with the absolute path to `server/server.js`.
- Server dependency installation now uses an explicit `--prefix` path and no longer requires `Push-Location` into the UNC server directory.
- Added an explicit Node.js major-version check and clearer startup diagnostics.

## 1.1.0 — 2026-09-28

- Added `PGPBox.vbs` as the preferred one-click Windows/UNC launcher with no CMD window.
- `start.ps1` now starts Node.js in the background, waits for `/api/health`, then opens the browser automatically.
- Existing healthy server instances are reused instead of starting a duplicate process.
- `index.html` now redirects direct `file://` openings to `http://127.0.0.1:3000/`.
- Added persistent launcher/server logs and a PID file under `logs/`.
- Added `stop.ps1` and `PGPBox_Stop.vbs` for controlled shutdown of the background server.
- Service-worker cache bumped to `pgpbox-v3` so the new startup/index behavior is not masked by an older cached shell.

## 1.2.0 — PasevSU UI/UX revision

- Renamed the user-facing project to **PasevSU PGP Toolbox**.
- Added complete BG/DE interface switching with persisted language preference.
- Added localized runtime dialogs/status text and translated dynamic UI output where controlled by the application.
- Added a four-part instruction panel to every one of the 17 primary tools.
- Enforced a single-open top-level accordion; opening a tool closes the previously open tool.
- Reworked form layout with `minmax(0,1fr)`, `min-width:0`, 100% control widths and mobile single-column breakpoints.
- Added long-value overflow protection for fingerprints, URLs and armored content.
- Added PasevSU header branding, PWA metadata, server identity, manifest generator identity and backup naming.
- Renamed the one-click launchers to `PasevSU_PGP_Toolbox.vbs` and `PasevSU_PGP_Toolbox_Stop.vbs`.
- Preserved the legacy IndexedDB name and legacy backup import compatibility to avoid data loss during upgrade.
- Responsive Chromium harness passed all 17 sections at 1024 px and 375 px with zero detected control overflow.
