# PasevSU ChronoSeal Vault Repository

Home Assistant repository for **PasevSU ChronoSeal Vault** — a fail-closed forensic cryptographic vault combining OpenPGP, OpenTimestamps, RFC 3161/PKI validation, evidence cases, cryptographic audit chains and sealed/exported evidence packages.

## Home Assistant architecture

ChronoSeal is packaged as a Home Assistant **App** with a single authenticated Ingress web service. It is intentionally not implemented as a large `custom_components` integration because the main workload is a self-contained web/crypto/evidence application rather than native HA entities/devices.

No host port is exposed. The main UI, OpenPGP Expert workspace, Admin/Preflight console and backend APIs share the same Ingress service on port 8099.

## Storage

Default runtime paths:
- `/data/evidence` — private persistent evidence cases;
- `/data/staging` — private atomic-ingest staging;
- `/share/chronoseal/import` — deliberate import/source exchange;
- `/share/chronoseal/export` — verified sealed-case copies;
- `/share/chronoseal/runtime/OtsCli.jar` — optional independent Java OpenTimestamps verifier.

Runtime paths outside `/data` and `/share` are rejected at startup.

## Crypto runtime authority

The deployable HA App does **not** contain the full `_crypto.7z` development/source archive. OpenPGP.js and OpenTimestamps are exact-version npm runtime dependencies. The source archive is audited separately in `SOURCE_ARCHIVE_AUDIT.json`.

An external `OtsCli.jar` is optional. It is never executed unless `java_ots_sha256` is configured and exactly matches the physical JAR. A matching hash is still not enough: the JAR must also pass its executable runtime probe.

## Release rule

Static/package/integration gates are not sufficient for FINAL status. The Home Assistant/Supervisor image must build successfully and the in-image runtime self-test must PASS the pinned OpenPGP and OpenTimestamps operations before a release can be marked final.
