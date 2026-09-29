# PasevSU ChronoSeal Vault Repository

Home Assistant repository for **PasevSU ChronoSeal Vault** — a fail-closed forensic cryptographic vault combining OpenPGP, OpenTimestamps, RFC 3161/PKI validation, evidence cases, cryptographic audit chains and sealed/exported evidence packages.

Add this Git repository URL to the Home Assistant App Store repositories. The app exposes no host port and is intended to be accessed through authenticated Home Assistant Ingress.

Storage is configurable from the app Configuration page:
- `/config/chronoseal/evidence` — primary evidence cases (inside the app-specific `addon_config` mapping)
- `/share/chronoseal/import` — import/source exchange directory
- `/share/chronoseal/export` — verified sealed-case copies
- `/config/chronoseal/staging` — temporary atomic-ingest staging

Paths outside `/config` and `/share` are rejected at startup.


## v3.2 storage options
Configure evidence, import, export and staging directories from the Home Assistant app configuration. Import files are copied through staging and verified with SHA-256/SHA-512 before becoming immutable originals. `max_upload_mib` bounds uploads/imports and `import_recursive` controls import scanning.

## GitHub source synchronization

Windows helper scripts are included under `tools/git-sync/`. They validate the Home Assistant repository and app source before every automatic commit/push and block runtime evidence/key material from source control. See `tools/git-sync/README.md`.
