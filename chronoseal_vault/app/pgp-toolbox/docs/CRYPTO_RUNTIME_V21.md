# PasevSU Crypto Runtime & `_crypto` Capability Layer — v2.1.1

The canonical external provider repository is sibling `PROJECT/_crypto`. Resolution order is `PASEVSU_CRYPTO_HOME`, sibling `_crypto`, project-local `_crypto`, then legacy `_crypto.lnk` on Windows.

This PGP application inspects only OpenPGP/browser-provider components relevant to its own functions. It does not expose or execute OpenTimestamps or unrelated `_crypto` projects.

OpenPGP.js is pinned to 6.3.1. A local source is accepted only when `openpgpjs/package.json` reports exactly 6.3.1 and `dist/openpgp.min.js` exists. jsPDF local source is accepted only at 4.2.1. QR uses the local `qrcodejs` implementation when present.

Every installed runtime bundle has a `.sha256` sidecar. A later startup rejects an existing runtime file if the sidecar is missing or the digest differs. Network bootstrap is disabled by default and requires `PASEVSU_ALLOW_VENDOR_DOWNLOAD=1`.

The runtime matrix distinguishes source detection from loaded-browser capability. PQ/T is enabled by neither source-file presence nor generic `DSA` names; it remains blocked until an exact runtime provider is exposed and tested.
