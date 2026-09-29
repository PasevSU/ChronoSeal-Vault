@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Import-Crypto.ps1" -Source "H:\custom_components\pasevsu_chronoseal_vault\_crypto"
if errorlevel 1 exit /b %errorlevel%
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Verify-Crypto.ps1"
