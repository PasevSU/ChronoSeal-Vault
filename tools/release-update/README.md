# ChronoSeal automatic release inbox

1. Copy exactly one full ChronoSeal release ZIP into repository-root `_release_inbox/`.
2. Optional but recommended: place `<archive>.sha256` next to it.
3. Run `powershell -ExecutionPolicy Bypass -File .\tools\release-update\Update-ChronoSealFromInbox.ps1` from the repository root.

The updater is fail-closed. It acquires the same watcher synchronization lock, requires a clean Git repository, extracts into a temporary staging directory, validates the staged release before modifying the repository, applies only controlled source surfaces, validates the installed state again, blocks release ZIP/7z artifacts from Git (except the intentionally pinned `chronoseal_vault/_crypto.7z`), commits, pushes, fetches and independently verifies the remote commit. On an apply/validation failure it rolls tracked source back to the original HEAD. The inbox is Git-ignored; `README.txt` is the only tracked file there.

Use `-NoPush` to stop after the local validated commit.
