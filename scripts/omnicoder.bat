@echo off
REM ============================================================
REM OmniCoder - CLI Wrapper for Windows CMD
REM Lanza qwen CLI con branding OmniCoder y carga .env auto
REM ============================================================
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

set "OMNI_DIR=%USERPROFILE%\.omnicoder"

REM Cargar .env si existe (provider activo)
if exist "%OMNI_DIR%\.env" (
    for /f "usebackq tokens=1,* delims==" %%a in ("%OMNI_DIR%\.env") do (
        set "%%a=%%b"
    )
)

REM Headless mode: si el primer arg es -p, saltar banner
if "%~1"=="-p" goto :launch

REM Banner OmniCoder
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
echo   168 agentes ^| 193 skills ^| 18 hooks ^| 21 commands
echo.

:launch
REM Pasar todo a qwen
qwen %*
