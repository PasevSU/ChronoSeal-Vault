# PasevSU PGP Toolbox v2.1.1

PasevSU PGP Toolbox is a local, server-required OpenPGP workbench for Windows/modern browsers. The canonical application origin is `http://127.0.0.1:3000`; `PasevSU_PGP_Toolbox.vbs` starts the dependency-free Node.js loopback server and opens the browser after an exact-version health check. Direct `file://`, Live Server and non-canonical origins are redirected to the canonical origin.

## Security & correctness baseline

v2.1.1 is a hardening release. It removes untrusted HTML insertion paths, enables a strict server CSP, restricts Host/Origin, makes the Node server dependency-free, makes IndexedDB key replacement atomic, blocks unprotected private-key imports, requires at least 16 characters for newly generated private-key passphrases, and upgrades encrypted backup creation to OpenPGP password encryption with Argon2id + AES-256 + RFC 9580 AEAD GCM.

Key manifests are public-only: private armored material is never embedded in manifest JSON. Private material can still be included in the explicitly encrypted backup workflow.

Revocation-certificate generation now creates a revoked clone with the selected OpenPGP reason and extracts the certificate from that clone. The stored key is not revoked until a certificate is explicitly applied. Third-party certification is intentionally limited to the generic certification operation exposed by the verified OpenPGP.js public API; unsupported level/expiration/notation controls were removed instead of being simulated.

## Cryptographic provider

The browser runtime is pinned to **OpenPGP.js 6.3.1** for this release. The project prefers a prebuilt exact-version bundle in the sibling `PROJECT/_crypto/openpgpjs` source tree. QR prefers `PROJECT/_crypto/qrcodejs`. PDF reports require the pinned jsPDF 4.2.1 runtime or an exact-version central source.

Vendor files are SHA-256 pinned locally after a verified local copy or an explicitly opted-in network bootstrap. On every later startup the runtime file must match its `.sha256` sidecar. The Node server independently refuses to serve a runtime vendor bundle whose sidecar does not match, and launcher health requires `vendorReady=true`. Network vendor download is disabled by default; set `PASEVSU_ALLOW_VENDOR_DOWNLOAD=1` only when an explicit bootstrap is intended.

The `_crypto` directory is never served by HTTP and its absolute path is not returned by the capability API.

## OpenPGP scope

The application contains OpenPGP key generation/import/inspection, exact-email discovery (local → WKD → verified VKS fallback), message encryption/decryption/signing/verification, detached signatures, keyserver publish/lookup, public manifests, revocation, generic third-party certification, encrypted backup/restore, file encryption/signing/decryption, session-key inspection, Web of Trust verification, advanced key lifecycle operations, policy negotiation and PasevSU Fortress.

PGP/MIME was removed from the claimed feature set in v2.1.1 because the previous UI depended on a provider that was not bundled or verified. It will not be advertised again until a real RFC 3156 provider has runtime tests.

OpenTimestamps and other non-PGP components in the central `_crypto` repository are intentionally outside this application and are not exposed through its runtime capability matrix.

## Policy engine

Every normal message/file encryption path now calls the Policy Engine before `openpgp.encrypt`. Available profiles are Modern Compatible, RFC 9580 v6 Strict, Legacy Interoperability, Forensic Read-Only, and RFC 9980 PQ/T. A `BLOCKED` policy result prevents encryption; there is no silent downgrade.

RFC 9980 PQ/T remains fail-closed unless the loaded browser provider exposes an exact ML-KEM/ML-DSA/SLH-DSA style runtime algorithm and the capability layer reports it. Classical `DSA`, `ECDSA`, or legacy EdDSA names do not count as PQ capability.

## Fortress

New small/in-memory encryption uses **Fortress V2**, which stores a complete copy of the outer header inside the encrypted inner envelope and rejects any outer/inner metadata mismatch. Legacy Fortress V1 remains decrypt-compatible only and its outer metadata is explicitly treated as unauthenticated. New large-file encryption uses **Fortress Streaming V3**. V3 places a canonical copy of the outer metadata inside the encrypted stream before the plaintext; decryption compares the authenticated inner manifest to the outer header before committing output. `SHA-512-CHAIN-V1` still verifies exact plaintext content independently of browser stream chunk boundaries.

Legacy Streaming V2 can be read only after an explicit warning because V2 did not bind its outer metadata cryptographically. New encryption never creates V2.

## Reports

The report engine creates technical German A4 PDF reports through jsPDF 4.2.1, with canonical JSON, SHA-256, SHA-512, 128-hex-character derived Page-IDs (`SHA-512(canonical report hash + page ordinal)`), QR payload, runtime/provider metadata and optional public-key inventory. Private-key material is never collected by the report engine. Bulgarian UI remains supported, but Bulgarian PDF generation is not advertised without a verified embedded Unicode font path.

## Start

Preferred Windows entry point: `PasevSU_PGP_Toolbox.vbs`. `start.bat` is the visible/debug alternative. The backend has no npm dependencies and requires Node.js 18+.

`setup_vendor.ps1` resolves browser crypto/report dependencies from the sibling `_crypto` repository. The canonical topology is:

```text
PROJECT/
├─ _WEB_pgp/   ← this project
└─ _crypto/    ← central cryptographic/vendor source repository
```

## Verification

Run `python verify_project.py` for the full static/release contract. Individual Node tests live under `tests/`. Runtime OpenPGP and jsPDF browser self-tests are included and become executable after the pinned vendor bundles are installed.

See `docs/SECURITY_HARDENING_V21.md`, `docs/CRYPTO_RUNTIME_V21.md`, `docs/PROVIDER_POLICY_V21.md`, `docs/FORTRESS_STREAMING_V3.md`, `docs/REPORT_ENGINE_V21.md` and `docs/TEST_REPORT.md`.
