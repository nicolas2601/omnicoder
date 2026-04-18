@echo off
REM ===========================================================================
REM omnicoder.cmd - Windows CMD wrapper around the `opencode` binary.
REM
REM Per feedback_ci_windows_bat.md:
REM   #1 always `call` nested .bat/.cmd (we call powershell directly so N/A).
REM   #6 PATH manipulation in installer uses PowerShell, not here.
REM   #8 doctor returns 1 on fresh runner; CI step must tolerate.
REM
REM This script stays minimal: it forwards to omnicoder.ps1 which holds the
REM real logic (PS is more robust on Windows than CMD parser quirks).
REM ===========================================================================
setlocal EnableExtensions EnableDelayedExpansion

set "OMNI_SCRIPT_DIR=%~dp0"
set "OMNI_PS1=%OMNI_SCRIPT_DIR%omnicoder.ps1"

if not exist "%OMNI_PS1%" (
    echo omnicoder: missing sibling omnicoder.ps1 at "%OMNI_PS1%" 1>&2
    exit /b 127
)

REM Forward every argument verbatim. %* preserves quoting for PowerShell -File.
powershell -NoProfile -ExecutionPolicy Bypass -File "%OMNI_PS1%" %*
set "RC=%errorlevel%"

endlocal & exit /b %RC%
