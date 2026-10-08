# READY JS PACKAGES

This directory is an organizational refactor of the uploaded JS project. The original source is preserved separately. Files are grouped by responsibility; duplicated files from the source are not silently rewritten.

## Recommended runtime order

1. `01-core`
2. `02-api`
3. `03-data-cache`
4. `05-forensics` / `06-hash-crypto`
5. `07-ots`
6. `08-pdf-report`
7. `09-ui-app`
8. `10-pgp` / `11-runtime-vendor`
9. `12-cli-build` only for Node/build entry points

## Important

- `04-transactions` is the functional transaction package boundary. It currently contains the transaction-related blockchain adapters found in the source; it is deliberately isolated so a dedicated `transactions.js` orchestrator can own pagination/cache/background loading.
- `90-legacy-pakages` preserves the existing `pakages` tree and its CryptoJS/OTS/PGP material without mixing it into the active application structure.
- `13-tests` contains tests/profiles and must not be loaded by production HTML.
- `11-runtime-vendor` contains browser/vendor bundles and must not be treated as application logic.

## Critical finding

`07-ots/timestamp-queue.js` resolves its package-local `ots-manager.js`, but its upgrade and verification functions are adapter-required stubs. `12-cli-build/main.js` imports `./lib/ots-manager.js`, which is absent. The queue and CLI must not be treated as production-ready until these gaps are resolved.
