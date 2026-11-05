@echo off
rem motion tool: one-click check and install for Windows
rem Double-click this file. Check only: run with --check
chcp 65001 >nul
set MODE=install
if /i "%~1"=="--check" set MODE=check
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0windows-setup.ps1" -Mode %MODE%
set CODE=%ERRORLEVEL%
if /i not "%MODE%"=="check" pause
exit /b %CODE%
