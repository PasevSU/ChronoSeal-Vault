# PasevSU ChronoSeal Vault v3.2.0-alpha10 — verification record

## Implemented closure upgrades
- Fresh pre-seal cryptographic preflight added.
- Original is rehashed from physical storage before finalization.
- OTS proof is freshly inspected and verified before finalization; cached BLOCKCHAIN_VERIFIED alone is insufficient.
- START DFN and STOP DigiCert RFC3161 artifacts are freshly revalidated with OpenSSL and PKI before finalization.
- Final manifest v4 records the preflight evidence and complete stable artifact inventory.
- Physical artifacts are rehashed before seal and again during seal verification.
- Existing seals are verified rather than blindly returned as valid.
- UI now exposes Fresh preflight, Finalize + seal, and Verify sealed case.
- Docker dependency versions remain exact; runtime self-test remains a mandatory image-build gate.

## Local package/static checks — PASS
- Release gate, completeness gate, JS syntax and JSON/YAML checks.
- Required API/UI wiring present.
- `_crypto.7z` pinned SHA-256 verified by the release gate.

## Local backend checks — PASS where executable here
- Backend starts and reports 3.2.0-alpha10.
- Streaming SHA-256/SHA-512 for `abc` independently matches known values.
- Missing OTS/runtime paths fail closed rather than returning success.
- Strict preflight cannot finalize an incomplete case.

## Mandatory external qualification — NOT CLAIMED
This environment has no Docker/Podman/7z runtime and cannot execute a Home Assistant image build. Therefore browser OpenPGP inside HA, extracted OTS runtime, live Bitcoin confirmation and live DFN/DigiCert transactions are not falsely marked PASS. The Docker build itself runs `runtime_selftest.js` and must fail if required runtime components are missing.
