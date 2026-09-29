# ChronoSeal Enterprise v3.3.0-alpha3 — executed tests

## PASS in this build workspace
- `git-provenance.js`: Node syntax PASS.
- Real temporary Git repository E2E: stage -> PRE_COMMIT_MANIFEST -> commit -> read commit/tree/parents -> POST_COMMIT_ATTESTATION -> independent HEAD/tree checks: PASS.
- `chain-orchestrator.js`: Node syntax PASS.
- Sequential chain test: PASS -> PENDING stops chain; second invocation retries the pending step and continues to final PASS.
- `identity-card.js`: Node syntax PASS (browser/OpenPGP runtime E2E is not available in this container).

## FAIL / not promoted to PASS
- OpenPGP Identity Card runtime generation+signature verification: FAIL for release qualification in this environment because browser OpenPGP runtime was not executable here.
- Full OpenTimestamps 0.4.9 donor runtime test: FAIL for release qualification because dependencies are not bundled in the donor archive and npm installation timed out in this environment.
- Home Assistant Supervisor image build / Ingress browser E2E: FAIL for release qualification because no Docker/Podman/Supervisor runtime is available here.
- Live RFC3161 / live OTS calendar / Bitcoin confirmation: not claimed as PASS by this build.

Required functionality is never represented as PASS merely from source presence.
