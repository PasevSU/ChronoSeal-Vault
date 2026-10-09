# PasevSU Provider / Policy Engine v2.1

Policy profiles are operation gates, not advisory labels.

- Modern Compatible: v4/v6, RSA >= 3072, valid encryption key required.
- RFC 9580 v6 Strict: v6 required, RSA >= 3072, valid encryption key required.
- Legacy Interoperability: v4/v6, RSA >= 2048, valid encryption key required.
- Forensic Read-Only: inspection only; it never authorizes new encryption.
- RFC 9980 PQ/T: v6 plus a verified runtime PQ/T provider and matching certificate algorithm are required.

`authorizeEncryption()` is called by normal message encryption and batch file encryption before `openpgp.encrypt`. Any runtime-integrity failure, certificate validation failure or policy mismatch produces `BLOCKED` and prevents encryption.

There is no silent downgrade. OpenPGP.js performs recipient preference negotiation only after the policy result is `READY`.
