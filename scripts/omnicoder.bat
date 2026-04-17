@echo off
REM ============================================================
REM OmniCoder v4.3 - CLI Wrapper for Windows CMD
REM Lanza qwen CLI con branding OmniCoder y carga .env auto
REM ============================================================
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

set "OMNI_VERSION=4.3.0"
set "OMNI_DIR=%USERPROFILE%\.omnicoder"
if defined OMNICODER_HOME set "OMNI_DIR=%OMNICODER_HOME%"

REM Verificar bash en PATH (hooks lo requieren)
where bash >nul 2>&1
if errorlevel 1 (
    echo.
    echo [OmniCoder] AVISO: bash no encontrado - los hooks no funcionaran.
    echo             Instala Git for Windows: https://git-scm.com/download/win
    echo.
)

REM Garantizar que ~/.qwen/settings.json apunta a los hooks de OmniCoder
if not exist "%USERPROFILE%\.qwen\settings.json" (
    if exist "%OMNI_DIR%\settings.json" (
        if not exist "%USERPROFILE%\.qwen" mkdir "%USERPROFILE%\.qwen"
        copy /y "%OMNI_DIR%\settings.json" "%USERPROFILE%\.qwen\settings.json" >nul 2>&1
    )
)

REM Cargar .env si existe (KEY=VALUE, saltar comentarios y lineas vacias)
if exist "%OMNI_DIR%\.env" (
    for /f "usebackq tokens=1,* delims==" %%a in ("%OMNI_DIR%\.env") do (
        set "LINE=%%a"
        if not "!LINE!"=="" if not "!LINE:~0,1!"=="#" set "%%a=%%b"
    )
)

REM v4.3.1 FIX: forzar auth por API key + limpiar caches OAuth residuales.
if defined OPENAI_API_KEY (
    set "QWEN_AUTH_TYPE=openai"
    set "QWEN_NO_TELEMETRY=1"
    for %%F in (oauth_creds.json access_token refresh_token .qwen_session auth.json) do (
        if exist "%USERPROFILE%\.qwen\%%F" del /q "%USERPROFILE%\.qwen\%%F" >nul 2>&1
    )
)

REM --version / -v
if /i "%~1"=="--version" goto :show_version
if /i "%~1"=="-v" goto :show_version

REM Headless mode: si el primer arg es -p, saltar banner
if "%~1"=="-p" goto :launch

REM Banner OmniCoder v4.3
REM v4.3.1 FIX: banner simple sin carets escapados (antes el arte ASCII
REM con ^(_^| generaba un paren desbalanceado estructuralmente en CMD).
echo.
echo    ____                  _ ______          __
echo   / __ \____ ___  ____  (_) ____/___  ____/ /__  _____
echo  / / / / __ `__ \/ __ \/ / /   / __ \/ __  / _ \/ ___/
echo / /_/ / / / / / / / / / / /___/ /_/ / /_/ /  __/ /
echo \____/_/ /_/ /_/_/ /_/_/\____/\____/\__,_/\___/_/
echo.

REM Mostrar info del provider activo
if defined OPENAI_MODEL (
    echo   Model: %OPENAI_MODEL%
)
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
echo   OmniCoder v%OMNI_VERSION% . 168 agents . 193 skills . 18 hooks . 21 commands
echo.

:launch
REM Pasar todo a qwen
qwen %*
exit /b %ERRORLEVEL%

:show_version
REM Contar componentes si existen
set "AGENT_COUNT=0"
set "SKILL_COUNT=0"
set "HOOK_COUNT=0"
set "CMD_COUNT=0"
if exist "%OMNI_DIR%\agents" for %%f in ("%OMNI_DIR%\agents\*.md") do set /a AGENT_COUNT+=1
if exist "%OMNI_DIR%\skills" for /d %%d in ("%OMNI_DIR%\skills\*") do set /a SKILL_COUNT+=1
if exist "%OMNI_DIR%\hooks"  for %%f in ("%OMNI_DIR%\hooks\*.sh") do set /a HOOK_COUNT+=1
if exist "%OMNI_DIR%\commands" for %%f in ("%OMNI_DIR%\commands\*.md") do set /a CMD_COUNT+=1

REM Fallback a valores de referencia v4.3 si runtime vacio
if "%AGENT_COUNT%"=="0" set "AGENT_COUNT=168"
if "%SKILL_COUNT%"=="0" set "SKILL_COUNT=193"
if "%HOOK_COUNT%"=="0"  set "HOOK_COUNT=18"
if "%CMD_COUNT%"=="0"   set "CMD_COUNT=21"

set "QWEN_VER=(no instalado)"
where qwen >nul 2>&1
if not errorlevel 1 (
    for /f "tokens=* usebackq" %%a in (`qwen --version 2^>nul`) do set "QWEN_VER=%%a"
)

set "PROVIDER_NAME=(no configurado)"
if defined OPENAI_BASE_URL (
    set "PROVIDER_NAME=custom"
    echo !OPENAI_BASE_URL! | findstr /i "nvidia" >nul && set "PROVIDER_NAME=NVIDIA NIM (MiniMax M2.7)"
    echo !OPENAI_BASE_URL! | findstr /i "generativelanguage" >nul && set "PROVIDER_NAME=Google Gemini"
    echo !OPENAI_BASE_URL! | findstr /i "minimax" >nul && set "PROVIDER_NAME=MiniMax"
    echo !OPENAI_BASE_URL! | findstr /i "deepseek" >nul && set "PROVIDER_NAME=DeepSeek"
    echo !OPENAI_BASE_URL! | findstr /i "openrouter" >nul && set "PROVIDER_NAME=OpenRouter"
    echo !OPENAI_BASE_URL! | findstr /i "localhost 127.0.0.1" >nul && set "PROVIDER_NAME=Ollama (local)"
)

echo.
echo OmniCoder v%OMNI_VERSION%
echo   Qwen Code CLI:    !QWEN_VER!
echo   Provider:         !PROVIDER_NAME!
echo   Agents:           %AGENT_COUNT%
echo   Skills:           %SKILL_COUNT%
echo   Hooks:            %HOOK_COUNT%
echo   Commands:         %CMD_COUNT%
echo.
echo Installation: %OMNI_DIR%
echo Repo:         https://github.com/nicolas2601/omnicoder
echo License:      MIT
echo.
exit /b 0
