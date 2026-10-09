# ChronoSeal Vault — Home Assistant architecture review

Candidate: **3.4.0-alpha6**  
Date: 2026-09-30

## Decision

ChronoSeal remains a Home Assistant **App** with one Ingress web server and one API authority. A large `custom_components` integration is not required for the current workload. Native HA integration should be added only for future entities/actions/events/devices that actually need Core integration.

## Alpha6 size/runtime finding

The previous `_crypto.7z` was physically inspected, not inferred. It contains 686 files and 62,863,680 uncompressed bytes. 53,251,781 bytes are `.git` metadata. It contains source trees for OpenPGP.js, JavaScript/TypeScript OpenTimestamps, JSEncrypt, QRCode.js and otsgo, but **no JAR files and no `OtsCli.jar`**.

The source checkout `javascript-opentimestamps` is version **0.4.9**, while the production runtime contract pins npm `opentimestamps` **0.4.6**. Alpha5 preferred the source checkout before the pinned npm engine, so a successful build could silently execute a version different from the declared runtime contract. Alpha6 corrects this: the exact contract-pinned npm CLI is authoritative and source checkout is fallback-only.

## Deployable runtime

The HA app now contains about 1.78 MB / 134 files before npm dependencies are installed during image build. The 52,146,174-byte source archive is no longer in the app build context and `p7zip` is no longer required.

OpenPGP.js 6.3.1 and OpenTimestamps 0.4.6 remain exact-version dependencies. QRCode.js and jsPDF browser assets remain bundled. The small `_crypto/` directory is retained only for runtime trust/metadata and its own manifest.

## Independent Java OTS

Java runtime is retained, but the verifier is externalized to `/share/chronoseal/runtime/OtsCli.jar`. It is fail-closed:

1. path must be under `/share` or `/data`;
2. `java_ots_sha256` must be empty or exactly 64 hexadecimal characters;
3. if the JAR exists but no pin is supplied, it is never executed;
4. a hash mismatch is never executed;
5. even a hash-matching JAR must pass `java -jar ... --help` before it is READY.

This preserves the independent-verifier capability without shipping an unrelated source archive.

## Qualification status

PASS: package completeness, integration gate, release gate, donor OpenPGP tests, runtime security gate, Admin allowlist rejection, Ingress-safe embedded UI, 20 MiB streaming hash, source `_crypto` manifest integrity.

BLOCKED for FINAL: the current execution environment cannot perform the actual Home Assistant/Supervisor Docker build and therefore cannot install/execute the exact in-image npm OpenPGP/OpenTimestamps runtimes. The source-tree self-test intentionally remains FAIL for those build-produced dependencies. No FINAL label is permitted until the built HA image passes the runtime self-test.
