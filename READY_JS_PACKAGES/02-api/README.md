# API package

Single HTTP/API boundary for application features. New components should use `HttpClient`/`API` rather than creating their own `fetch()` transport.

Existing blockchain adapters are retained here as adapters; they are not the central transport.

**Module-format mismatch:** `api.js`, `http.js`, `web3.js`, and `wkd-utils.js` use ES modules, but this package's `package.json` declares CommonJS. Fix the package boundary before importing those files from Node.
