# ChronoSeal Enterprise v3.3.0-alpha2 — test results

Date: 2026-09-29

## PASS in this environment
- Repository validator / release gate.
- Package completeness: all required checks true.
- JavaScript syntax for active application scripts.
- Backend startup with configurable test root and port.
- `/api/status` reports version 3.3.0-alpha2 and writable test storage roots.
- `/api/text/manifest` preserves exact UTF-8 bytes and independently matched SHA-256/SHA-512; manifest exposes MD5, SHA-1, SHA-224, SHA-256, SHA-384, SHA-512, SHA3-224/256/384/512 and RIPEMD-160.
- `/api/text/case` preserved CRLF/trailing spaces in the tested byte stream, created immutable original, text evidence manifest and audit log; SHA-256 independently matched Python hashlib.
- Static HTML references resolve, except `vendor/openpgp.min.js`, which is intentionally generated from pinned openpgp@6.3.1 during Docker build.
- No duplicate static HTML IDs.
- Legacy donor modules are retained but are not loaded by the active UI.

## Corrections made after testing alpha1
- Version coherence fixed to 3.3.0-alpha2 across config/package/Docker build argument.
- Exact recipient e-mail matching replaces substring matching.
- Sign+Encrypt no longer silently ignores the Sign option; signing key/passphrase are required when enabled.
- Multi-recipient encryption now has an active implementation and requires at least two validated active Vault keys.
- Decrypt signature policy is wired to a supplied verification key; required signatures fail closed when absent/invalid.
- Implemented Enterprise profiles now actually apply slot configuration; RFC9580/v6 and Universal MAX remain informational/blocked until their real builders exist.
- ECC profile uses Curve25519 as a curve label instead of fictitious ECC 4096 metadata.
- Generated keys retain inspected packet/algorithm metadata; RSA requested bit length is checked when the runtime exposes the bit count.
- Text digest verification validates hex and expected digest length for SHA-256/SHA-512.

## Not PASS / not claimed complete
- Real Home Assistant Supervisor Docker image build/install/Ingress browser E2E: Docker/Podman unavailable here.
- Browser OpenPGP cryptographic E2E: build-generated OpenPGP browser bundle is unavailable until the Docker/npm build succeeds.
- Runtime self-test requiring installed openpgp/opentimestamps packages: npm install could not complete in this environment; no PASS claimed.
- OTS live stamping/Bitcoin confirmation: executable OTS runtime is absent in this test container.
- Live DFN/DigiCert RFC3161 network transaction: not executed in this test cycle.
- RFC9580/v6 generation: not implemented/claimed.
- True primary+bound-subkey Universal MAX: not implemented/claimed.
- WKD backend discovery, real OpenPGP revocation certificates, Fortress V2/V3 and full report-engine integration remain subsequent Master Inventory stages.
