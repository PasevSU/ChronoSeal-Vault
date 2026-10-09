# PasevSU local loopback server v2.1.1

The server uses only Node.js built-ins; there are no npm runtime dependencies.

It binds to `127.0.0.1:3000`, enforces the canonical Host/Origin boundary, sends strict CSP/security headers, serves only the application allowlist (`/`, `/style`, `/scripts`, `/icons`, `/tests`) and never serves `_crypto`, `server`, logs or project metadata files.

API:

- `GET /api/health` — exact application/version health.
- `GET /api/crypto-capabilities` — controlled PGP/provider metadata; no absolute `_crypto` path is returned.
- `GET /api/discover-email?email=...` — exact-email local discovery backend: WKD first, then keys.openpgp.org VKS fallback.
- `POST /api/publish/:host` — public-key publishing to a fixed allowlist.
- `GET /api/lookup/:host/:fingerprint` — public-key lookup through a fixed allowlist.

WKD uses HTTPS only, public DNS-address validation, a pinned resolved address for the request, TLS SNI for the original hostname and manual redirect validation.
