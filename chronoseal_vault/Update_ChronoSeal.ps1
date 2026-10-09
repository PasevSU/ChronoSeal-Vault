$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
& node (Join-Path $Root 'updater.js') $Root
exit $LASTEXITCODE
