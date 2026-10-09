# v2.1.1 Security & Correctness Hardening

The v2.1.1 audit was performed against the uploaded v2.0.1 release package, not against an inferred project tree.

Closed issues:

- DOM XSS sinks for OpenPGP UID/notation/keyserver/file-name/error data are escaped; strict CSP is enabled.
- public manifest export no longer contains armored private keys.
- revocation reason/text now reach the OpenPGP operation and the certificate is generated from a revoked clone.
- unsupported certification level/expiration/notation controls were removed; generic certification is verified after creation.
- false PQ detection no longer matches classical DSA/ECDSA/legacy EdDSA names.
- normal message and batch-file encryption are fail-closed through the Policy Engine.
- Fortress Streaming V3 authenticates outer metadata through an encrypted inner manifest; V2 is legacy-read only with warning.
- Service Worker no longer caches cryptographic/vendor bundles.
- WKD requests pin a validated public DNS address and validate every redirect target.
- loopback API enforces canonical Host/Origin and does not expose `_crypto` absolute paths.
- the Node server has zero npm dependencies.
- browser vendor files receive SHA-256 sidecars and are rechecked at startup.
- IndexedDB whole-key-store writes are atomic.
- binary `.pgp` batch decryption is detected from the actual packet bytes, not the filename extension.
- new private keys and passphrase changes require at least 16 characters and use Argon2 S2K.
- unprotected private-key import is blocked; legacy backup restore re-protects unprotected private material.
- Web of Trust edges require cryptographic `verifyAllUsers` validation rather than issuer-Key-ID matching alone.
- PGP/MIME is no longer advertised because no verified RFC 3156 provider was present.
- non-PGP `_crypto` components are not surfaced by this PGP-only application.

Remaining explicit boundaries, not hidden defects:

- Windows VBS/PowerShell process behavior must still be exercised on Windows; this Linux build environment cannot execute Windows Script Host.
- Full browser OpenPGP/jsPDF runtime tests require the real pinned vendor bundles. They are included as target self-tests but are not claimed as executed when the bundle is absent.
- Legacy Fortress Streaming V2 can be decrypted for compatibility, but the UI explicitly warns that its outer metadata was not cryptographically bound.
- OpenPGP.js 6.3.2 appeared on npm on the build date, while the audited GitHub release index still showed 6.3.1. v2.1.1 deliberately keeps 6.3.1 until the newer release is independently reviewed and runtime-tested.

## v2.1.1 precision hardening

- Static HTTP allowlisting is evaluated **after** URL decoding and POSIX normalization; each request must remain inside its explicitly allowed first-level directory. Encoded slash/dot traversal is rejected.
- Runtime OpenPGP.js, QR and jsPDF bundles are server-gated by their `.sha256` sidecars. `/api/health` exposes only boolean/path-free vendor state and the launcher requires `vendorReady=true`.
- Each project copy receives a local random 128-bit instance identifier under `logs/instance.id`; the launcher will not silently reuse or terminate a same-version PasevSU server belonging to another project copy.
- Persistent removal of private-key passphrase protection is no longer available.
- Key Manifest and Key Inspector await asynchronous primary/subkey expiration APIs, preventing false `never expires` results.
- Keyserver refresh merges public updates into a stored private-key container when present so revocations/certifications survive later lifecycle operations.
- In-memory Fortress V2 binds the visible outer metadata to an encrypted inner copy. Legacy V1 is decrypt-only compatible.
