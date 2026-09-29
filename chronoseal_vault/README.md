# PasevSU ChronoSeal Vault — Home Assistant Forensic Crypto Vault

Version 3.2.0-alpha10. Storage locations are configurable in Home Assistant add-on options. Required paths must be under `/config` or `/share`; startup fails closed when a configured path is unusable. Successfully sealed cases can be hash-verified and copied automatically to the configured export directory.


Ingress-only OpenPGP + forensic evidence add-on. No host TCP port is published (`ports: {}`). Evidence is persisted under `/config/ots_generator` by default.

## Evidence case lifecycle

`Create OTS` first writes `/config/ots_generator/<filename>/original/<filename>`, fsyncs it, recalculates SHA-256/SHA-512 from the stored copy, and refuses further processing on mismatch. The original is made read-only and is never used as an OTS mutation target. Filename collisions with different content are isolated using a SHA-256 suffix.

The persistent OTS worker uses `_crypto/javascript-opentimestamps/ots-cli.js` when present (Java OtsCli fallback), preserves every pre-upgrade proof, and repeatedly performs upgrade -> info -> verify with exponential backoff until an explicit Bitcoin block attestation is present and verification succeeds. Restarting the add-on does not lose pending state.

Generated PGP/XAdES/PAdES/report artifacts can be attached to the same evidence case and are re-hashed into the evidence manifest.

## RFC3161 BRIDGE + strict PKI

START provider: DFN (`https://zeitstempel.dfn.de/`). STOP provider: DigiCert (`http://timestamp.digicert.com`). Provider hosts are allowlisted; arbitrary TSA URLs are not accepted.

START timestamps the canonical evidence manifest. STOP is refused until START passes strict validation and timestamps a deterministic closing digest linking the canonical manifest, START token hash, evidence ID and closing provider.

Each TSA directory preserves TSQ, TSR, TST, OpenSSL reply/verify output, extracted certificates, chain material, CRL/OCSP request/response evidence and JSON validation records. Strict PASS requires: query/response binding, SHA-256 message imprint, token extraction, critical exclusive timeStamping EKU, signer validity at genTime, X.509 chain, provider root fingerprint pin, no revocation result, and at least one validated CRL or GOOD OCSP result. `REVOKED` is always a hard failure; unavailable revocation evidence is never reported as PASS.

Pinned roots:
- DFN-Verein Community Root CA 2022 SHA-256: `3cdc2c9e9e5a36cb5888fd1796cb912f846253b682c1b32057532033510c7bb6`
- DigiCert Trusted Root G4 SHA-256: `552f7bdcf1a7af9e6ce672017f4f12abf77240c78e761ac203d1d9d20ac89988`

Controlled additional root certificates may be placed in `_crypto/trust/` before build. They are merged with the container CA store, but provider fingerprint pinning still applies.

## Crypto runtime

The image installs OpenSSL and the CA store directly. `_crypto/jsencrypt` is detected as an optional RSA helper source checkout; it does not replace OpenPGP.js, OpenTimestamps or OpenSSL. `_crypto/javascript-opentimestamps` remains the preferred OTS engine.

The browser OpenPGP runtime is pinned to OpenPGP.js 6.3.1 during image build. Private OpenPGP key material remains browser-side/IndexedDB; the evidence backend does not store browser private keys in Home Assistant state.

## Closure

A case reports `closed=true` only when all three gates are true: OTS `BLOCKCHAIN_VERIFIED`, strict DFN START verified, and strict DigiCert STOP verified.


## Configured storage
`evidence_root`, `import_root`, `export_root`, and `staging_root` are runtime paths. `import_recursive` controls scanning and `max_upload_mib` bounds evidence ingestion. Import is copy-only: the configured source file is never modified or deleted.
