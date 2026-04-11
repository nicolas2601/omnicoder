@echo off
REM ============================================================
REM Qwen Con Poderes - Instalador para Windows
REM Instala Qwen Code CLI + 168 agentes + 193 skills
REM ============================================================
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

echo.
echo ========================================================
echo         QWEN CON PODERES - INSTALADOR WINDOWS
echo    168 Agentes + 193 Skills para Qwen Code CLI
echo ========================================================
echo.

REM ──────────────────────────────────────────────────────────
REM PASO 1: Verificar requisitos
REM ──────────────────────────────────────────────────────────
echo [1/5] Verificando requisitos...

where node >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: Node.js no esta instalado.
    echo Descargalo desde https://nodejs.org ^(v20 o superior^)
    echo.
    echo   winget install OpenJS.NodeJS.LTS
    echo   o descarga desde https://nodejs.org/en/download
    echo.
    pause
    exit /b 1
)

for /f "tokens=1 delims=." %%a in ('node -v') do set NODE_VER=%%a
set NODE_VER=%NODE_VER:v=%
if %NODE_VER% LSS 20 (
    echo ERROR: Node.js v20+ requerido.
    pause
    exit /b 1
)
echo   [OK] Node.js encontrado

where npm >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: npm no esta instalado.
    pause
    exit /b 1
)
echo   [OK] npm encontrado

where git >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: git no esta instalado.
    echo   winget install Git.Git
    pause
    exit /b 1
)
echo   [OK] git encontrado

REM ──────────────────────────────────────────────────────────
REM PASO 2: Instalar Qwen Code CLI
REM ──────────────────────────────────────────────────────────
echo.
echo [2/5] Instalando Qwen Code CLI...

where qwen >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo   [OK] Qwen Code ya esta instalado
) else (
    echo   Instalando @qwen-code/qwen-code...
    call npm install -g @qwen-code/qwen-code@latest
    if %ERRORLEVEL% neq 0 (
        echo.
        echo   Metodo alternativo: Ejecuta en CMD como Administrador:
        echo   curl -fsSL -o %%TEMP%%\install-qwen.bat https://qwen-code-assets.oss-cn-hangzhou.aliyuncs.com/installation/install-qwen.bat ^&^& %%TEMP%%\install-qwen.bat --source qwenchat
        echo.
    ) else (
        echo   [OK] Qwen Code instalado
    )
)

REM ──────────────────────────────────────────────────────────
REM PASO 3: Detectar directorio del repo
REM ──────────────────────────────────────────────────────────
echo.
echo [3/5] Detectando archivos del repo...

set "SCRIPT_DIR=%~dp0"
set "REPO_DIR=%SCRIPT_DIR%.."

if not exist "%REPO_DIR%\agents" (
    echo ERROR: No se encontro la carpeta agents\ en %REPO_DIR%
    echo Asegurate de ejecutar este script desde el repo clonado.
    pause
    exit /b 1
)
echo   [OK] Carpetas agents/ y skills/ encontradas

REM ──────────────────────────────────────────────────────────
REM PASO 4: Instalar Agentes
REM ──────────────────────────────────────────────────────────
echo.
echo [4/5] Instalando agentes en %%USERPROFILE%%\.qwen\agents\...

set "QWEN_AGENTS=%USERPROFILE%\.qwen\agents"
if not exist "%QWEN_AGENTS%" mkdir "%QWEN_AGENTS%"

set AGENT_COUNT=0
for %%f in ("%REPO_DIR%\agents\*.md") do (
    copy /y "%%f" "%QWEN_AGENTS%\%%~nxf" >nul
    set /a AGENT_COUNT+=1
)
echo   [OK] !AGENT_COUNT! agentes instalados

REM ──────────────────────────────────────────────────────────
REM PASO 5: Instalar Skills
REM ──────────────────────────────────────────────────────────
echo.
echo [5/5] Instalando skills en %%USERPROFILE%%\.qwen\skills\...

set "QWEN_SKILLS=%USERPROFILE%\.qwen\skills"
if not exist "%QWEN_SKILLS%" mkdir "%QWEN_SKILLS%"

set SKILL_COUNT=0
for /d %%d in ("%REPO_DIR%\skills\*") do (
    xcopy /e /i /y "%%d" "%QWEN_SKILLS%\%%~nxd" >nul 2>&1
    set /a SKILL_COUNT+=1
)
echo   [OK] !SKILL_COUNT! skills instaladas

REM ──────────────────────────────────────────────────────────
REM Copiar QWEN.md
REM ──────────────────────────────────────────────────────────
if exist "%REPO_DIR%\QWEN.md" (
    copy /y "%REPO_DIR%\QWEN.md" "%USERPROFILE%\.qwen\QWEN.md" >nul
    echo   [OK] QWEN.md copiado
)

REM ──────────────────────────────────────────────────────────
REM Resumen final
REM ──────────────────────────────────────────────────────────
echo.
echo ========================================================
echo            INSTALACION COMPLETADA
echo ========================================================
echo.
echo   Agentes instalados: !AGENT_COUNT! agentes
echo   Skills instaladas:  !SKILL_COUNT! skills
echo.
echo PARA EMPEZAR:
echo   1. Abre una nueva terminal (CMD o PowerShell)
echo   2. Escribe: qwen
echo   3. Authenticate: /auth
echo   4. Ver agentes: /agents manage
echo   5. Usar skill:  /skills engineering-backend-architect
echo.
echo CATEGORIAS DISPONIBLES:
echo   academic (5) ^| design (8) ^| engineering (27)
echo   game-dev (20) ^| marketing (29) ^| paid-media (7)
echo   product (5) ^| project-mgmt (6) ^| sales (8)
echo   spatial-computing (6) ^| specialized (30)
echo   support (6) ^| testing (8)
echo.
pause
