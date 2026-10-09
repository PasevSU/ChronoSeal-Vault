@echo off
set ROOT=%~dp0
node "%ROOT%updater.js" "%ROOT%"
exit /b %ERRORLEVEL%
