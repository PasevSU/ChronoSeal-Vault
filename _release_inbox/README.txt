DROP ONE ChronoSeal release .zip HERE.

Then run from repository root:
  powershell -ExecutionPolicy Bypass -File .\tools\release-update\Update-ChronoSealFromInbox.ps1

The updater stages, validates, applies, re-validates, commits and pushes the release.
The ZIP itself is never committed.
Optional: add <archive>.sha256 containing the expected SHA-256.
