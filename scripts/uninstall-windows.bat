@echo off
REM ============================================================
REM Qwen Con Poderes v2 - Desinstalador para Windows (CMD)
REM Wrapper que invoca uninstall-windows.ps1
REM ============================================================

powershell -ExecutionPolicy Bypass -File "%~dp0uninstall-windows.ps1" %*
