# 3.2.0-alpha10 — Configured Storage & Verified Import

- All evidence/import/export/staging roots are Home Assistant options and runtime-bound.
- Upload staging now physically uses the configured staging root.
- Added fail-closed import inventory and verified import-to-case pipeline.
- Import traversal and symlink escapes are rejected.
- Added configurable recursive import scanning and maximum upload size.
- Export remains post-seal and hash-verified with EXPORT_RECEIPT.json.
- Forensic audit chain is mandatory and can no longer be disabled by a cosmetic option.

## 3.0.0-alpha8
- Added fresh cryptographic preflight before finalization.
- Added existing RFC3161 token revalidation for START/STOP.
- Finalization now rehashes original, freshly verifies OTS, revalidates TSA/PKI, verifies audit, and prechecks physical artifacts.
- Added final manifest v4 and seal v3.
- Added UI controls for preflight, finalize/seal and seal verification.
- Existing sealed cases are cryptographically verified before being reported as already sealed.
# 3.0.0-alpha2 — Consolidation foundation

- Added shared TextEvidenceEngine backend.
- Added exact UTF-8 text hash matrix: MD5, SHA-1, SHA-224/256/384/512, SHA3-224/256/384/512, RIPEMD-160.
- Added canonical text evidence manifest with encoding, normalization policy, byte length and manifest binding hashes.
- Added standalone Text Hash & Timestamp Manifest UI.
- OpenPGP text encryption now records plaintext and ciphertext hash sets and creates a linked evidence case.
- Added automatic RFC3161 START attempt for encrypted-text evidence cases.
- Preserves the rc6 repository layout and existing OTS/TSA evidence backend.
- This alpha is a consolidation foundation; the complete v2.1.1 frontend modules are not yet physically restored.

# Changelog

## 1.0.0-rc5
- Added controlled `_crypto` import and SHA-256 integrity manifest tooling for the local Windows crypto source tree.
- Added runtime discovery for JavaScript/Java/TypeScript OpenTimestamps source, OpenPGP.js and JSEncrypt.
- Added independent Java OpenTimestamps cross-verification when a Java OtsCli.jar is present; blockchain confirmation requires every available independent verifier to agree.
- Preserved the persistent OTS upgrade worker, immutable original, RFC3161 BRIDGE and strict TSA PKI validation from rc4.
- The TypeScript OpenTimestamps checkout is reported as source-only until a supported built CLI is present; it is never falsely reported as an executing verifier.


## 1.0.0-rc4
- Added strict RFC3161 TSA PKI Evidence Engine.
- Extracts and preserves TSA certificates from the CMS TimeStampToken.
- Requires critical Time Stamping EKU, certificate validity at TSA genTime, X.509 chain verification and provider-specific root fingerprint pinning.
- Captures CRL and OCSP evidence where advertised by the signer/issuer certificate; REVOKED is a hard failure and unavailable revocation data is not mislabeled PASS.
- Added controlled `_crypto/trust/` anchors merged with the system CA bundle while retaining provider root pinning.
- Restricted TSA destinations to the configured DFN and DigiCert provider hosts to remove the arbitrary-URL SSRF path.
- Added JSEncrypt runtime discovery as an optional RSA helper; it does not replace OpenPGP.js/OpenSSL/OTS.
- Home Assistant `evidence_root` option is now exported to the backend service.
- Preserved rc2/rc3 immutable-original backup, OTS persistent confirmation worker, canonical START binding and deterministic STOP closing digest.

## 1.0.0-rc3
- Added canonical evidence manifest for RFC3161 START binding.
- Added BRIDGE roles: DFN START and DigiCert STOP.
- START/STOP preserve TSQ, TSR, TST and OpenSSL verification artifacts.
- STOP requires verified START.

## 1.0.0-rc2
- Immutable, hash-verified original backup under `/config/ots_generator/<filename>/original/` before OTS submission.
- Persistent OTS upgrade/info/verify worker until explicit Bitcoin confirmation.
- Upgrade history, audit JSONL, manifests and generated-artifact ingestion.

## 1.0.0-rc1
- Added Evidence & Timestamp Center, backend hashing, OTS/RFC3161 endpoints and Ingress-only artifact access.

## 3.0.0-alpha6
- Runtime presence no longer implies readiness: OTS candidates must execute `--help` successfully.
- Added build-time `runtime_selftest.js`; mandatory runtime failures abort the image build.
- OpenPGP browser readiness requires the generated `vendor/openpgp.min.js`, not merely a source checkout.
- Pinned OpenTimestamps dependency to exactly 0.4.6 instead of a caret range.

## 3.0.0-alpha7
- Streaming SHA-256/SHA-512 request hashing and temp-file evidence/artifact ingestion.
- fsync + atomic no-replace commit for streamed files.
- Immutable artifact namespace: idempotent same-content replay; collision fail-closed.
- Central sealed-case write guard across artifact, OTS and TSA mutations.
- Worker uses per-case lock and skips sealed cases.
- Seal v2 binds a stable physical evidence inventory and rehashes every bound file during verification.
- One-byte post-seal artifact tampering now fails seal verification.
- OTS Java independent `info -v`; explicit redundancy status.
- Dead `.ots` import UI removed.
- PKI chain verification anchored to the exact pinned root certificate and CRL freshness checked at TSA genTime.
- Runtime self-test v2 adds OpenPGP cryptographic roundtrip and local OTS proof-info execution.

## 3.3.0-alpha3
- Added verified Git provenance engine with PRE_COMMIT_MANIFEST and POST_COMMIT_ATTESTATION.
- Added resumable fail-closed sequential Chain Orchestrator with hash-linked records.
- Added Cryptographic Identity Card UI/module: signed canonical manifest, embedded public key, primary and subkey identifiers, verification and JSON/HTML/public-key export.
- Preserved existing ChronoSeal visual design and navigation.

## 3.3.0-alpha4
- Reworked runtime qualification around a versioned `RUNTIME_CONTRACT.json`.
- Bundled a pinned known-good OTS fixture and verify its SHA-256 before OTS execution.
- Removed the obsolete assumption that OTS must live under `_crypto/javascript-opentimestamps`; runtime discovery now tests the pinned npm CLI and recursively discovers allowed bundled OTS CLI/JAR candidates.
- Docker build now emits the complete runtime self-test JSON before failing closed.
- Runtime self-test now verifies Java execution in addition to OpenSSL/OpenPGP/OTS/crypto-manifest checks.
- Fixed forensic chain canonical JSON hashing for nested objects.
- Git provenance now hashes exact staged Git blobs and verifies staged blob OIDs against the resulting commit.
- Strengthened release validation for runtime contract, fixture integrity and Docker diagnostic wiring.

## 3.4.0-alpha6 — HA slim runtime / fail-closed OTS authority
- Removed the 49.7 MiB `_crypto.7z` development/source archive from the deployable Home Assistant app; the archive contained 686 source/VCS files and no `OtsCli.jar`.
- Corrected an OTS version-authority defect: bundled source checkout was OpenTimestamps 0.4.9 while the runtime contract pins npm `opentimestamps` 0.4.6. The contract-pinned npm engine is now authoritative and source checkout is fallback-only.
- Runtime self-test now verifies the exact installed OpenTimestamps package version and requires the pinned primary CLI to parse the known `.ots` fixture.
- Added optional external Java OTS verifier at `/share/chronoseal/runtime/OtsCli.jar`; it is never executed unless `java_ots_sha256` exactly matches the file.
- Removed `p7zip` and full source extraction from the HA image build while retaining Java runtime for the explicitly pinned independent verifier.
- Added an explicit Ingress static-asset allowlist: donor source/server/docs/log files remain available for qualification but are no longer HTTP-readable.
- Repaired `qualification_donor_assets.sha256` to use portable relative paths and made donor PDF/font hash verification a release-gate requirement.
- Added `runtime-security-gate` to the Admin allowlist; it verifies unpinned/corrupt Java rejection, arbitrary-script rejection, streaming hash integrity and static-source non-exposure.
