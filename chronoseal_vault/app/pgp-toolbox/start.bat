@echo off
setlocal
REM PasevSU PGP Toolbox - direct self-starting JS launcher.
REM Normal path: start.bat -> start.js -> server\server.js
where node.exe >nul 2>nul
if errorlevel 1 (
    echo.
    echo [ERROR] Node.js 18+ is required and node.exe was not found in PATH.
    pause
    exit /b 1
)
node.exe "%~dp0start.js"
set "EXIT_CODE=%ERRORLEVEL%"
if not "%EXIT_CODE%"=="0" (
    echo.
    echo [ERROR] PasevSU PGP Toolbox JS launcher exited with code %EXIT_CODE%.
    echo See logs\launcher.log and logs\server.stderr.log for details.
    pause
)
exit /b %EXIT_CODE%
