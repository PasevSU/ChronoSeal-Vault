# ChronoSeal Vault Git synchronization

Use the repository root as the working folder. `Initialize-ChronoSealRepo.ps1` connects it to GitHub and refuses to overwrite an existing remote `main` history. `Watch-ChronoSealRepo.ps1` batches filesystem changes, runs all source gates, commits only if they pass, and pushes to `main`. `Install-ChronoSealWatcher.ps1` installs that watcher as a Windows Scheduled Task at logon.

Runtime evidence, staging/import/export content, timestamp proofs and common private-key formats are excluded from Git and are also blocked at commit time.
