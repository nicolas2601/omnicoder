@echo off
REM ============================================================
REM Qwen Con Poderes v3.5 - Instalador para Windows (CMD)
REM 168 agentes + 193 skills + 16 hooks + 20 commands + settings
REM ============================================================
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

echo.
echo ========================================================
echo    QWEN CON PODERES v2.0 - INSTALADOR WINDOWS
echo    168 Agentes + 193 Skills + 7 Hooks + 11 Commands
echo    Token optimization ^| Security hooks ^| Auto-routing
echo ========================================================
echo.

REM ── PASO 1: Verificar requisitos ──
echo [1/8] Verificando requisitos...

where node >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo   ERROR: Node.js no esta instalado.
    echo   winget install OpenJS.NodeJS.LTS
    pause & exit /b 1
)
for /f "tokens=1 delims=." %%a in ('node -v') do set NODE_VER=%%a
set NODE_VER=%NODE_VER:v=%
if %NODE_VER% LSS 20 (
    echo   ERROR: Node.js v20+ requerido.
    pause & exit /b 1
)
echo   [OK] Node.js

where npm >nul 2>&1
if %ERRORLEVEL% neq 0 ( echo   ERROR: npm no instalado. & pause & exit /b 1 )
echo   [OK] npm

where git >nul 2>&1
if %ERRORLEVEL% neq 0 ( echo   ERROR: git no instalado. winget install Git.Git & pause & exit /b 1 )
echo   [OK] git

REM ── PASO 2: Qwen Code CLI ──
echo.
echo [2/8] Qwen Code CLI...
where qwen >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo   [OK] Ya instalado
) else (
    call npm install -g @qwen-code/qwen-code@latest
    echo   [OK] Instalado
)

REM ── PASO 3: Detectar repo ──
echo.
echo [3/8] Detectando archivos...
set "SCRIPT_DIR=%~dp0"
set "REPO_DIR=%SCRIPT_DIR%.."
if not exist "%REPO_DIR%\agents" (
    echo   ERROR: No se encontro agents\ en %REPO_DIR%
    pause & exit /b 1
)
echo   [OK] Repo detectado

REM ── PASO 4: Instalar Agentes ──
echo.
echo [4/8] Instalando agentes...
set "QWEN_AGENTS=%USERPROFILE%\.qwen\agents"
if not exist "%QWEN_AGENTS%" mkdir "%QWEN_AGENTS%"
set AC=0
for %%f in ("%REPO_DIR%\agents\*.md") do ( copy /y "%%f" "%QWEN_AGENTS%\%%~nxf" >nul & set /a AC+=1 )
echo   [OK] !AC! agentes instalados

REM ── PASO 5: Instalar Skills ──
echo.
echo [5/8] Instalando skills...
set "QWEN_SKILLS=%USERPROFILE%\.qwen\skills"
if not exist "%QWEN_SKILLS%" mkdir "%QWEN_SKILLS%"
set SC=0
for /d %%d in ("%REPO_DIR%\skills\*") do ( xcopy /e /i /y "%%d" "%QWEN_SKILLS%\%%~nxd" >nul 2>&1 & set /a SC+=1 )
echo   [OK] !SC! skills instaladas

REM ── PASO 6: Instalar Hooks ──
echo.
echo [6/8] Instalando hooks...
set "QWEN_HOOKS=%USERPROFILE%\.qwen\hooks"
if not exist "%QWEN_HOOKS%" mkdir "%QWEN_HOOKS%"
set HC=0
for %%f in ("%REPO_DIR%\hooks\*.sh") do ( copy /y "%%f" "%QWEN_HOOKS%\%%~nxf" >nul & set /a HC+=1 )
echo   [OK] !HC! hooks instalados

REM ── PASO 7: Instalar Commands ──
echo.
echo [7/8] Instalando slash commands...
set "QWEN_CMDS=%USERPROFILE%\.qwen\commands"
if not exist "%QWEN_CMDS%" mkdir "%QWEN_CMDS%"
set CC=0
for %%f in ("%REPO_DIR%\commands\*.md") do ( copy /y "%%f" "%QWEN_CMDS%\%%~nxf" >nul & set /a CC+=1 )
echo   [OK] !CC! commands instalados

REM ── PASO 8: Config ──
echo.
echo [8/8] Configurando...
if exist "%REPO_DIR%\QWEN.md" ( copy /y "%REPO_DIR%\QWEN.md" "%USERPROFILE%\.qwen\QWEN.md" >nul & echo   [OK] QWEN.md )
if exist "%REPO_DIR%\config\settings.json" ( copy /y "%REPO_DIR%\config\settings.json" "%USERPROFILE%\.qwen\settings.json" >nul & echo   [OK] settings.json )
if not exist "%USERPROFILE%\.qwen\logs" mkdir "%USERPROFILE%\.qwen\logs"

REM ── Resumen ──
echo.
echo ========================================================
echo           INSTALACION COMPLETADA v2.0
echo ========================================================
echo.
echo   Agentes:  !AC!    Skills:  !SC!
echo   Hooks:    !HC!    Commands: !CC!
echo.
echo   PARA EMPEZAR:
echo     qwen                    Iniciar Qwen Code
echo     /agents manage          Ver agentes
echo     /skills                 Ver skills
echo     /review                 Code review
echo     /ship                   Test+lint+commit+push
echo     /audit                  Auditoria completa
echo     /handoff                Guardar progreso
echo.
echo   HOOKS ACTIVOS:
echo     security-guard    Bloquea comandos peligrosos
echo     pre-edit-guard    Protege archivos sensibles
echo     skill-router      Auto-sugiere skills
echo     session-init      Carga sesion anterior
echo.
pause
