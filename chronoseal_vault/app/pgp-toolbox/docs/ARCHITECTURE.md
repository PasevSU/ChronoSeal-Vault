# PasevSU PGP Toolbox v2.1.1 — Architecture

## Trust boundaries

1. `PasevSU_PGP_Toolbox.vbs` / `start.ps1` is the Windows process launcher.
2. `setup_vendor.ps1` resolves pinned browser providers from the sibling `PROJECT/_crypto` repository and creates SHA-256 sidecars.
3. `server/server.js` is a dependency-free Node.js loopback server bound only to `127.0.0.1`.
4. The browser application is valid only at `http://127.0.0.1:3000`.
5. `_crypto` is never a static HTTP root. The capability API exposes only controlled metadata, never the absolute path or file contents.

## Browser security

The server sends CSP with `script-src 'self'`, `connect-src 'self'`, `object-src 'none'`, `base-uri 'none'`, `frame-ancestors 'none'` and related hardening headers. Bootstrap is an external script. Untrusted OpenPGP/network strings are escaped or inserted with `textContent`.

Service Worker behavior is network-only and clears old PasevSU caches. It does not cache the application shell or vendor cryptographic bundles.

## Persistence

Key records are stored in IndexedDB. Whole-key-store replacement is a single read/write transaction. Snapshots are local rollback points. New and imported private keys are expected to remain passphrase-protected; explicit passphrase removal remains a clearly warned expert operation.

## Network

Browser code talks only to the loopback server. Keyserver and WKD traffic is performed server-side. WKD uses public-address validation, DNS pinning for each HTTPS request and manual redirect validation. API Host/Origin checks are fail-closed.

## Cryptography

OpenPGP operations use pinned OpenPGP.js 6.3.1. Normal encryption is gated by `scripts/policy-engine.js`. RFC 9980 PQ/T is not emulated. Fortress is explicitly a PasevSU custom container layered on OpenPGP operations and is not represented as a standard OpenPGP message format.
