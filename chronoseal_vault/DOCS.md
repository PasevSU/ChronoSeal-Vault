# PasevSU ChronoSeal Vault — Home Assistant

The UI is exposed only through Home Assistant Ingress; no host port is published.

Evidence is stored under `/config/ots_generator` by default. With `addon_config:rw`, `/config` is the add-on/app-specific persistent configuration directory, not the whole Home Assistant configuration tree.

On OTS creation the application creates a case, stores and re-hashes the original, creates the `.ots` proof and persists confirmation state. Pending timestamps are retried by the worker. A case must not be described as blockchain verified until `verify` succeeds and a Bitcoin block attestation is parsed.

RFC3161 START/STOP raw request/response/token and validation artifacts are stored inside the same case. Revocation or trust failures remain failures/unknown; they are not converted into PASS.
