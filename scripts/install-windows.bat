@echo off
REM ============================================================
REM OmniCoder v4.2 - Instalador para Windows (CMD)
REM 168 agentes + 193 skills + 18 hooks + 21 commands + settings
REM ============================================================
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

echo.
echo ========================================================
echo    OMNICODER v4.2.0 - INSTALADOR WINDOWS
echo    168 Agentes + 193 Skills + 18 Hooks + 21 Commands
echo    Multi-provider ^| Cognitive routing ^| Subagent verify
echo ========================================================
echo.

REM ── Upgrade detection ──
if exist "%USERPROFILE%\.omnicoder\.version" (
    set /p INSTALLED_VER=<"%USERPROFILE%\.omnicoder\.version"
    echo   Version instalada: !INSTALLED_VER!
    echo   Version nueva:     4.2.0
    if "!INSTALLED_VER!"=="4.2.0" (
        echo   Ya tienes la version actual.
        echo   Usa scripts\install-windows.bat --force para reinstalar.
        pause & exit /b 0
    )
    set /p "UPGRADE=  Actualizar? [Y/n]: "
    if /i "!UPGRADE!"=="n" ( echo Cancelado. & pause & exit /b 0 )
) else if exist "%USERPROFILE%\.qwen\agents" (
    echo   [!!] Instalacion legacy detectada: Qwen Con Poderes en %%USERPROFILE%%\.qwen\
    echo   Esta actualizacion instalara OmniCoder v4.0 en %%USERPROFILE%%\.omnicoder\
    echo   Tu memoria en .qwen\ NO se eliminara.
    set /p "UPGRADE=  Continuar? [Y/n]: "
    if /i "!UPGRADE!"=="n" ( echo Cancelado. & pause & exit /b 0 )
)
echo.

REM ── PASO 1: Verificar requisitos ──
echo [1/11] Verificando requisitos...

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
echo [2/11] Qwen Code CLI...
where qwen >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo   [OK] Ya instalado
) else (
    call npm install -g @qwen-code/qwen-code@latest
    echo   [OK] Instalado
)

REM ── PASO 3: Detectar repo ──
echo.
echo [3/11] Detectando archivos...
set "SCRIPT_DIR=%~dp0"
set "REPO_DIR=%SCRIPT_DIR%.."
if not exist "%REPO_DIR%\agents" (
    echo   ERROR: No se encontro agents\ en %REPO_DIR%
    pause & exit /b 1
)
echo   [OK] Repo detectado

REM ── PASO 4: Instalar Agentes ──
echo.
echo [4/11] Instalando agentes...
set "OMNI_AGENTS=%USERPROFILE%\.omnicoder\agents"
if not exist "%OMNI_AGENTS%" mkdir "%OMNI_AGENTS%"
set AC=0
for %%f in ("%REPO_DIR%\agents\*.md") do ( copy /y "%%f" "%OMNI_AGENTS%\%%~nxf" >nul & set /a AC+=1 )
echo   [OK] !AC! agentes instalados

REM ── PASO 5: Instalar Skills ──
echo.
echo [5/11] Instalando skills...
set "OMNI_SKILLS=%USERPROFILE%\.omnicoder\skills"
if not exist "%OMNI_SKILLS%" mkdir "%OMNI_SKILLS%"
set SC=0
for /d %%d in ("%REPO_DIR%\skills\*") do ( xcopy /e /i /y "%%d" "%OMNI_SKILLS%\%%~nxd" >nul 2>&1 & set /a SC+=1 )
echo   [OK] !SC! skills instaladas

REM ── PASO 6: Instalar Hooks ──
echo.
echo [6/11] Instalando hooks...
set "OMNI_HOOKS=%USERPROFILE%\.omnicoder\hooks"
if not exist "%OMNI_HOOKS%" mkdir "%OMNI_HOOKS%"
set HC=0
for %%f in ("%REPO_DIR%\hooks\*.sh") do ( copy /y "%%f" "%OMNI_HOOKS%\%%~nxf" >nul & set /a HC+=1 )
echo   [OK] !HC! hooks instalados

REM ── PASO 7: Instalar Commands ──
echo.
echo [7/11] Instalando slash commands...
set "OMNI_CMDS=%USERPROFILE%\.omnicoder\commands"
if not exist "%OMNI_CMDS%" mkdir "%OMNI_CMDS%"
set CC=0
for %%f in ("%REPO_DIR%\commands\*.md") do ( copy /y "%%f" "%OMNI_CMDS%\%%~nxf" >nul & set /a CC+=1 )
echo   [OK] !CC! commands instalados

REM ── PASO 8: Config y CLI wrapper ──
echo.
echo [8/11] Configurando...
if exist "%REPO_DIR%\OMNICODER.md" ( copy /y "%REPO_DIR%\OMNICODER.md" "%USERPROFILE%\.omnicoder\OMNICODER.md" >nul & echo   [OK] OMNICODER.md )
if exist "%REPO_DIR%\config\settings.json" ( copy /y "%REPO_DIR%\config\settings.json" "%USERPROFILE%\.omnicoder\settings.json" >nul & echo   [OK] settings.json )
if not exist "%USERPROFILE%\.omnicoder\logs" mkdir "%USERPROFILE%\.omnicoder\logs"

REM Instalar CLI wrapper (omnicoder.bat)
if exist "%REPO_DIR%\scripts\omnicoder.bat" (
    copy /y "%REPO_DIR%\scripts\omnicoder.bat" "%USERPROFILE%\.omnicoder\omnicoder.bat" >nul
    echo   [OK] omnicoder.bat (CLI wrapper)
)
if exist "%REPO_DIR%\scripts\omnicoder.ps1" (
    copy /y "%REPO_DIR%\scripts\omnicoder.ps1" "%USERPROFILE%\.omnicoder\omnicoder.ps1" >nul
    echo   [OK] omnicoder.ps1 (CLI wrapper)
)

REM Verificar si %USERPROFILE%\.omnicoder esta en PATH
echo %PATH% | findstr /i ".omnicoder" >nul
if %ERRORLEVEL% neq 0 (
    echo.
    echo   [!!] Para usar el comando "omnicoder" desde cualquier terminal:
    echo        Agrega %USERPROFILE%\.omnicoder al PATH del sistema.
    echo        Ejecuta en PowerShell como Admin:
    echo        [Environment]::SetEnvironmentVariable("Path", $env:Path + ";%USERPROFILE%\.omnicoder", "User"^)
)

REM ── PASO 9: Instalar memoria (skeleton) ──
echo.
echo [9/11] Instalando memoria persistente...
set "OMNI_MEM=%USERPROFILE%\.omnicoder\memory"
if not exist "%OMNI_MEM%" mkdir "%OMNI_MEM%"
if exist "%REPO_DIR%\memory" (
    for %%f in ("%REPO_DIR%\memory\*.md") do (
        if not exist "%OMNI_MEM%\%%~nxf" ( copy /y "%%f" "%OMNI_MEM%\%%~nxf" >nul )
    )
    echo   [OK] Memoria instalada
) else (
    echo   [OK] Directorio de memoria creado
)

REM ── PASO 10: Construir indice de skills ──
echo.
echo [10/11] Construyendo indice de skills...
where bash >nul 2>&1
if %ERRORLEVEL% equ 0 (
    bash "%REPO_DIR%\scripts\build-skill-index.sh" 2>nul
    echo   [OK] Indice construido
) else (
    echo   [!!] bash no encontrado - indice se construira en primera ejecucion
)

REM ── PASO 11: Setup de provider (API key) ──
echo.
echo [11/11] Setup de provider (API key)...
if exist "%USERPROFILE%\.omnicoder\.env" (
    echo   [!!] Ya existe %USERPROFILE%\.omnicoder\.env
    echo        Para cambiar: powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%setup-provider.ps1"
) else (
    set /p "SETUPNOW=  Configurar API key ahora? [Y/n]: "
    if /i not "!SETUPNOW!"=="n" (
        if exist "%SCRIPT_DIR%setup-provider.ps1" (
            powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%setup-provider.ps1"
        ) else (
            echo   [!!] setup-provider.ps1 no encontrado
        )
    ) else (
        echo   Saltado. Cuando quieras: powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%setup-provider.ps1"
    )
)

REM ── Save version marker ──
echo 4.2.0> "%USERPROFILE%\.omnicoder\.version"

REM ── Resumen ──
echo.
echo ========================================================
echo           INSTALACION COMPLETADA v4.2.0
echo ========================================================
echo.
echo   Agentes:  !AC!    Skills:  !SC!
echo   Hooks:    !HC!    Commands: !CC!
echo.
echo   PARA EMPEZAR:
echo     qwen                    Iniciar OmniCoder
echo     /agents manage          Ver agentes
echo     /skills                 Ver skills
echo     /review                 Code review
echo     /ship                   Test+lint+commit+push
echo     /audit                  Auditoria completa
echo     /handoff                Guardar progreso
echo     /verify-last            Auditoria del ultimo subagent
echo.
echo   HOOKS ACTIVOS (18 total):
echo     security-guard          Bloquea comandos peligrosos
echo     pre-edit-guard          Protege archivos sensibles
echo     skill-router            Routing cognitivo con BM25
echo     session-init            Carga sesion anterior
echo     memory-loader           Carga memoria persistente
echo     subagent-inject         Contrato a subagents
echo     subagent-verify         Verifica subagents
echo     subagent-error-recover  Detecta errores 400
echo     provider-failover       Auto-failover de API
echo     token-tracker           Tracking de consumo
echo     + 8 hooks de aprendizaje y soporte
echo.
echo   Cambiar provider: bash scripts\switch-provider.sh nvidia^|gemini^|...
echo.
pause
