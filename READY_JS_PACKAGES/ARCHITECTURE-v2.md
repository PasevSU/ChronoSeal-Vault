# READY JS PACKAGES v2

## Runtime boundaries
- `01-core`: shared application/core logic.
- `02-api`: Node HTTP/API servers and browser API client (`browser-index.mjs`).
- `03-data-cache`: data loading/synchronisation.
- `04-transactions`: browser transaction component, max 100/page, cache-first + background refresh.
- `05-forensics`: forensic acquisition/extraction and hashing. No UI dependencies.
- `06-hash-crypto`: CryptoJS/vendor cryptographic primitives.
- `07-ots`: OpenTimestamps implementation and queue adapter.
- `08-pdf-report`: report/PDF presentation layer.
- `09-ui-app`: browser UI only.
- `10-pgp`: PKI/PGP functionality used by TSA/API validation.
- `11-runtime-vendor`: third-party runtime assets only.
- `12-cli-build`: build/launcher tooling.
- `13-tests`: tests/profiles.
- `90-legacy-pakages`: untouched legacy compatibility material.

## Dependency direction
`core -> api/data -> domain packages -> ui`

UI must not contain forensic acquisition, cryptographic primitives, OTS server code, or Node filesystem access.

## Known intentional boundary
The Node API server may consume `10-pgp/pki-engine.js`; browser code must not import it.

## OTS queue
`07-ots/timestamp-queue.js` imports the package-local CommonJS `ots-manager.js`, although `07-ots/package.json` declares `"type": "module"`; the manager's upgrade and verification functions are also adapter-required stubs. `12-cli-build/main.js` imports the absent `12-cli-build/lib/ots-manager.js`. `opentimestamps.browser.min.js` is a CDN URL placeholder, not executable JavaScript. The Node OTS queue, CLI, and browser adapter therefore remain incomplete and must not be treated as production-ready.
