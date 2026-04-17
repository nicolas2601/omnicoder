@echo off
REM ============================================================
REM OmniCoder - CLI Wrapper (Windows CMD / .cmd)
REM
REM Carga ~/.omnicoder/.env, muestra banner, lanza qwen.
REM Funciona en cmd.exe nativo, PowerShell (invoca cmd /c), y
REM Git Bash (aunque ahi es mas comun usar el script 'omnicoder').
REM ============================================================
setlocal EnableDelayedExpansion EnableExtensions
chcp 65001 >nul 2>&1

set "OMNI_DIR=%USERPROFILE%\.omnicoder"
if defined OMNICODER_HOME set "OMNI_DIR=%OMNICODER_HOME%"

REM --- Garantizar que bash este en PATH (hooks lo requieren) ---
where bash >nul 2>&1
if errorlevel 1 (
    echo.
    echo [OmniCoder] ERROR: bash no encontrado en PATH.
    echo            Los hooks no funcionaran sin Git Bash o WSL.
    echo            Instala Git for Windows: https://git-scm.com/download/win
    echo.
    echo Para continuar sin hooks, edita ~/.qwen/settings.json
    echo y remueve la seccion "hooks" ^(no recomendado^).
    echo.
    endlocal & exit /b 1
)

REM --- Asegurar que settings.json de qwen apunta a los hooks de OmniCoder ---
if not exist "%USERPROFILE%\.qwen\settings.json" (
    if exist "%OMNI_DIR%\settings.json" (
        if not exist "%USERPROFILE%\.qwen" mkdir "%USERPROFILE%\.qwen"
        copy /y "%OMNI_DIR%\settings.json" "%USERPROFILE%\.qwen\settings.json" >nul
    )
)

REM --- Cargar .env si existe (parse KEY=VALUE, ignorar comentarios) ---
if exist "%OMNI_DIR%\.env" (
    for /f "usebackq tokens=1,* delims==" %%a in ("%OMNI_DIR%\.env") do (
        set "LINE=%%a"
        REM Saltar comentarios y lineas vacias
        if not "!LINE:~0,1!"=="#" if not "!LINE!"=="" (
            set "%%a=%%b"
        )
    )
)

REM --- v4.3.1 FIX: forzar auth por API key y limpiar caches de OAuth ---
REM Sin esto, qwen seguia pidiendo auth interactivo aunque hubiese API key en
REM .env porque detectaba oauth_creds.json o tokens cacheados de sesiones previas.
if defined OPENAI_API_KEY (
    set "QWEN_AUTH_TYPE=openai"
    set "QWEN_NO_TELEMETRY=1"
    for %%F in (oauth_creds.json access_token refresh_token .qwen_session auth.json) do (
        if exist "%USERPROFILE%\.qwen\%%F" del /q "%USERPROFILE%\.qwen\%%F" >nul 2>&1
    )
)

REM --- Headless mode: primer arg "-p" -> skip banner ---
if "%~1"=="-p" goto :launch
if "%~1"=="--prompt" goto :launch

REM --- Banner ---
echo.
echo    ____                  _ ______          __
echo   / __ \____ ___  ____  (_) ____/___  ____/ /__  _____
echo  / / / / __ `__ \/ __ \/ / /   / __ \/ __  / _ \/ ___/
echo / /_/ / / / / / / / / / / /___/ /_/ / /_/ /  __/ /
echo \____/_/ /_/ /_/_/ /_/_/\____/\____/\__,_/\___/_/
echo.

if defined OPENAI_MODEL echo   Model:    %OPENAI_MODEL%
if defined OPENAI_BASE_URL (
    set "PROVIDER_NAME=custom"
    echo !OPENAI_BASE_URL! | findstr /i "nvidia" >nul && set "PROVIDER_NAME=NVIDIA NIM"
    echo !OPENAI_BASE_URL! | findstr /i "generativelanguage" >nul && set "PROVIDER_NAME=Google Gemini"
    echo !OPENAI_BASE_URL! | findstr /i "minimax" >nul && set "PROVIDER_NAME=MiniMax"
    echo !OPENAI_BASE_URL! | findstr /i "deepseek" >nul && set "PROVIDER_NAME=DeepSeek"
    echo !OPENAI_BASE_URL! | findstr /i "openrouter" >nul && set "PROVIDER_NAME=OpenRouter"
    echo !OPENAI_BASE_URL! | findstr /i "localhost 127.0.0.1" >nul && set "PROVIDER_NAME=Ollama (local)"
    echo   Provider: !PROVIDER_NAME!
)
echo   168 agentes ^| 193 skills ^| 18 hooks ^| 21 commands
echo.

:launch
REM --- Lanzar qwen con todos los args ---
where qwen >nul 2>&1
if errorlevel 1 (
    echo [OmniCoder] ERROR: qwen no encontrado. Reinstala:
    echo            npm install -g @qwen-code/qwen-code@latest
    endlocal & exit /b 1
)
qwen %*
set "RC=%ERRORLEVEL%"
endlocal & exit /b %RC%
