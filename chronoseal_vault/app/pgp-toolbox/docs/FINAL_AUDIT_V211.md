# PasevSU PGP Toolbox v2.1.1 — Final Precision Audit

Date: 2026-09-28

This audit was performed from a clean extraction of the user-supplied v2.1.0 ZIP and then repeated after the v2.1.1 fixes.

## Additional defects found after the v2.1.0 hardening pass

1. Encoded `/scripts/%2f..%2f...` paths could pass the pre-decode prefix check and reach files outside the intended static subdirectory while remaining inside the project root.
2. The loopback server did not independently enforce the SHA-256 sidecars for browser vendor bundles when started outside the normal launcher.
3. Same-version server detection did not distinguish two different PasevSU project copies on port 3000.
4. `Key.getExpirationTime()` and `Subkey.getExpirationTime()` were used synchronously in Manifest/Inspector paths even though OpenPGP.js returns Promises.
5. Keyserver refresh updated the public copy only; a stored private-key container could remain stale.
6. Persistent passphrase removal contradicted the v2.1 policy that unprotected private-key persistence is forbidden.
7. Non-streaming Fortress still wrote V1 and did not authenticate all visible outer metadata.
8. PDF and canonical JSON exports could independently capture different `generatedAt` values and therefore different Report-IDs for otherwise identical report data.

All eight items are corrected in v2.1.1 and have regression assertions.

## Remaining explicit boundaries

- OpenPGP.js 6.3.1 remains pinned. 6.3.2 is not silently adopted without target runtime regression.
- The actual Windows VBS/PowerShell execution path cannot be executed in the Linux build environment; it is statically audited. The dependency-free Node server and vendor resolver contracts are executed separately.
- Real browser cryptographic and jsPDF runtime self-tests require the user's sibling `_crypto` bundles and are shipped under `tests/runtime_openpgp_v21.*` and `tests/runtime_report_v21.*`.
- Legacy Fortress V1 and Streaming V2 can be decrypted for compatibility but their outer metadata is explicitly not treated as authenticated.
- Bulgarian PDF output remains disabled until a verified Unicode TTF provider is integrated; the BG application UI remains supported.
