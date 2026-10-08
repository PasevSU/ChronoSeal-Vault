# OpenTimestamps

OTS timestamping, verification, calendar/notary operations and browser adapter.

**Packaging defects found in source:** `timestamp-queue.js` imports `./ots-manager.js`, but the manager is CommonJS while this package declares `"type": "module"`; its upgrade and verification functions are also adapter-required stubs. `12-cli-build/main.js` imports `./lib/ots-manager.js`, which is absent. `opentimestamps.browser.min.js` contains only a CDN URL, although `ots-adapter.js` expects it to be executable code. Do not mark the Node OTS queue/CLI or browser adapter as production-ready until these gaps are resolved.
