# ChronoSeal Vault 3.3.0-alpha4 — Critical Segment Audit

## Release classification
This package is a **release candidate for Home Assistant aarch64 qualification**, not a claimed installable release. The previous alpha3 HA build is recorded as FAIL because `runtime_selftest.js` returned exit code 9. Alpha4 preserves fail-closed behavior and makes the exact JSON failure visible in the Supervisor build log.

## 1. Repository / version contract — PASS (static)
`config.yaml`, `package.json`, and Docker `BUILD_VERSION` are cross-checked by `release_gate.py`. Required runtime-contract and OTS fixture files are release-critical.

## 2. Crypto archive — PASS (integrity), runtime capability pending
Pinned `_crypto.7z` SHA-256 remains `d200d6369db93acbf9334f9b6f5869538aaef713b3062c6b53b2aada8908eb13`. Docker verifies this before extraction. Alpha3 HA logs proved extraction and a generated manifest over 686 files. Integrity of bytes does not by itself prove OTS capability.

## 3. Runtime contract — PASS (static), HA runtime pending
Added `tools/RUNTIME_CONTRACT.json`. It binds OpenPGP 6.3.1, OpenTimestamps 0.4.6, crypto-archive SHA-256, required capabilities, and the pinned OTS fixture SHA-256.

## 4. OpenPGP — static PASS, HA runtime pending
Docker installs exact `openpgp` version and exports the browser bundle. Runtime self-test performs key generation, decrypt, detached sign and verify. This exact aarch64 execution must PASS in Home Assistant before runtime qualification.

## 5. OpenTimestamps — structural defect corrected, HA runtime pending
Removed the obsolete requirement that OTS source must exist at `_crypto/javascript-opentimestamps`. Self-test first tests the exact npm-installed CLI and also discovers allowed `ots-cli.js`/`OtsCli.jar` candidates inside the pinned crypto bundle. A known `.ots` fixture is shipped independently and SHA-256 checked before `info -v` execution. Presence alone never yields PASS.

## 6. Docker / Home Assistant — alpha3 FAIL; alpha4 pending
The Docker self-test still exits non-zero on any required failure. Unlike alpha3, its full JSON is printed to the build log before the layer fails. No `|| true` bypass exists. Actual HA aarch64 alpha4 build has not been executed in this environment.

## 7. Crypto manifest — PASS (static logic); HA regeneration pending
Manifest generation hashes every extracted file. Verification rejects missing files, root escape and SHA-256 mismatch. Alpha3 HA build verified 686 files. Alpha4 must regenerate inside the image.

## 8. Forensic chain — PASS (executed unit scenario)
Nested canonicalization was replaced with recursive deterministic canonical JSON. A nested-object chain record was executed successfully and received a deterministic record SHA-256.

## 9. Git provenance — PASS (executed temporary-repository scenario)
Pre-commit hashes now come from exact Git index blob bytes (`git cat-file blob`), not mutable working-tree files. Post-commit verification compares every staged blob OID with the resulting commit tree. Executed test passed `headMatches`, `treeMatches`, `commitObjectReadable`, and `stagedBlobsMatchCommit`.

## 10. POST attestation lifecycle — WARNING
`POST_COMMIT_ATTESTATION.json` is necessarily created after the commit it attests. It is not claimed to be contained in that same commit. A later evidence/commit policy is still required for persistent publication of this post-commit record.

## 11. Watcher / full-chain concurrency — WARNING
A shared repository lock between the automatic watcher and Full Chain Git provenance remains required before both are allowed to commit concurrently. Alpha4 does not claim this concurrency problem solved.

## 12. UI / Identity Card — static syntax only
Current visual design/navigation is preserved. No redesign was performed. Identity Card browser runtime has not been executed here; therefore runtime status remains unqualified rather than PASS.

## 13. RFC3161 / PKI — source retained; live network qualification pending
No live DFN/DigiCert TSA, OCSP or CRL transaction was executed in this environment. Existing functionality was not removed.

## 14. Release gate — PASS (executed static gate)
`package_completeness.js`, `release_gate.py`, and repository validation pass with the new runtime contract and fixture checks. These are source/release-integrity checks, not a substitute for the HA aarch64 image build.

## Promotion rule
Do not promote alpha4 beyond release-candidate status unless the Home Assistant Supervisor build shows the full runtime self-test JSON with `ok: true`, Docker image creation completes, the app starts under Ingress, and the runtime status endpoint confirms required engines. Any required failure is FAIL; it must not be relabeled NOT TESTED.
