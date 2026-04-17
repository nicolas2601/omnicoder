@echo off
REM ============================================================
REM OmniCoder v4.3 - Instalador para Windows (CMD nativo)
REM Compatible con cmd.exe, PowerShell (invoca cmd /c), y Git Bash.
REM
REM Flags:
REM   /SKIP_CLI   No instalar/actualizar qwen CLI (npm)
REM   /FORCE      Sobreescribir sin preguntar (incluye memoria)
REM   /DOCTOR     Solo diagnostico, no instala
REM   /HELP       Muestra ayuda
REM
REM Exit codes:
REM   0 exito   1 prereq faltante   2 path invalido   3 error copia
REM ============================================================
setlocal EnableDelayedExpansion EnableExtensions
chcp 65001 >nul 2>&1

REM Habilitar colores ANSI en Windows 10+ (no rompe en versiones viejas)
for /f "tokens=2 delims=[]" %%V in ('ver') do set "WIN_VER=%%V"

set "VERSION=4.3.0"
set "OMNI_HOME=%USERPROFILE%\.omnicoder"
set "QWEN_HOME=%USERPROFILE%\.qwen"
set "SCRIPT_DIR=%~dp0"
set "REPO_DIR=%SCRIPT_DIR%.."

REM Normalizar REPO_DIR (quitar trailing backslash y el ".." literal)
for %%I in ("%REPO_DIR%") do set "REPO_DIR=%%~fI"

REM ── Parseo de flags ──
set "SKIP_CLI=0"
set "FORCE=0"
set "DOCTOR_ONLY=0"
:parse_args
if "%~1"=="" goto :args_done
if /i "%~1"=="/SKIP_CLI" set "SKIP_CLI=1"
if /i "%~1"=="--skip-cli" set "SKIP_CLI=1"
if /i "%~1"=="/FORCE" set "FORCE=1"
if /i "%~1"=="--force" set "FORCE=1"
if /i "%~1"=="/DOCTOR" set "DOCTOR_ONLY=1"
if /i "%~1"=="--doctor" set "DOCTOR_ONLY=1"
if /i "%~1"=="/HELP" goto :show_help
if /i "%~1"=="--help" goto :show_help
if /i "%~1"=="/?" goto :show_help
if /i "%~1"=="-h" goto :show_help
shift
goto :parse_args
:args_done

echo.
echo ========================================================
echo    OMNICODER v%VERSION% - INSTALADOR WINDOWS (CMD)
echo    168 Agentes + 193 Skills + 18 Hooks + 21 Commands
echo    Multi-provider ^| Cognitive routing ^| Subagent verify
echo ========================================================
echo.

if "%DOCTOR_ONLY%"=="1" goto :doctor

REM ── Upgrade detection ──
if exist "%OMNI_HOME%\.version" (
    set /p INSTALLED_VER=<"%OMNI_HOME%\.version"
    echo   Version instalada: !INSTALLED_VER!
    echo   Version nueva:     %VERSION%
    if /i "!INSTALLED_VER!"=="%VERSION%" (
        if "%FORCE%"=="0" (
            echo   Ya tienes la version actual.
            echo   Usa /FORCE para reinstalar.
            endlocal & exit /b 0
        )
    )
    if "%FORCE%"=="0" (
        set /p "UPGRADE=  Actualizar? [Y/n]: "
        if /i "!UPGRADE!"=="n" ( echo Cancelado. & endlocal & exit /b 0 )
    )
) else if exist "%QWEN_HOME%\agents" (
    echo   [!!] Instalacion legacy detectada (OmniCoder pre-rebrand en .qwen\)
    echo        OmniCoder v%VERSION% se instalara en %OMNI_HOME%\
    echo        Tu memoria en .qwen\memory NO se eliminara.
    if "%FORCE%"=="0" (
        set /p "UPGRADE=  Continuar? [Y/n]: "
        if /i "!UPGRADE!"=="n" ( echo Cancelado. & endlocal & exit /b 0 )
    )
)
echo.

REM ── PASO 1: Verificar requisitos ──
echo [1/11] Verificando requisitos...

REM --- node >= 20 ---
where node >nul 2>&1
if errorlevel 1 (
    echo   ERROR: Node.js no esta instalado.
    echo          Ejecuta: winget install OpenJS.NodeJS.LTS
    endlocal & exit /b 1
)
for /f "tokens=* usebackq" %%a in (`node -v`) do set "NODE_RAW=%%a"
set "NODE_MAJOR=!NODE_RAW:v=!"
for /f "tokens=1 delims=." %%b in ("!NODE_MAJOR!") do set "NODE_MAJOR=%%b"
if !NODE_MAJOR! LSS 20 (
    echo   ERROR: Node.js v20+ requerido. Tienes !NODE_RAW!
    endlocal & exit /b 1
)
echo   [OK] Node.js !NODE_RAW!

REM --- npm ---
where npm >nul 2>&1
if errorlevel 1 ( echo   ERROR: npm no instalado. & endlocal & exit /b 1 )
echo   [OK] npm

REM --- git ---
where git >nul 2>&1
if errorlevel 1 (
    echo   ERROR: git no instalado. Ejecuta: winget install Git.Git
    endlocal & exit /b 1
)
echo   [OK] git

REM --- bash (Git Bash o WSL) ---
where bash >nul 2>&1
if errorlevel 1 (
    echo   [!!] bash no encontrado en PATH - los hooks NO funcionaran.
    echo        Instala Git for Windows: https://git-scm.com/download/win
    echo        (incluye Git Bash con bash, jq, md5sum, awk, grep, sed)
    if "%FORCE%"=="0" (
        set /p "NOBASH=  Continuar sin bash? [y/N]: "
        if /i not "!NOBASH!"=="y" ( echo Cancelado. & endlocal & exit /b 1 )
    )
) else (
    echo   [OK] bash
)

REM --- jq (los hooks lo requieren) ---
if not exist "%OMNI_HOME%\bin" mkdir "%OMNI_HOME%\bin" 2>nul
where jq >nul 2>&1
if errorlevel 1 (
    if exist "%OMNI_HOME%\bin\jq.exe" (
        set "PATH=%OMNI_HOME%\bin;%PATH%"
        echo   [OK] jq ^(local en %OMNI_HOME%\bin^)
    ) else (
        echo   [!!] jq no instalado - descargando a %OMNI_HOME%\bin\jq.exe...
        set "JQ_URL=https://github.com/jqlang/jq/releases/latest/download/jq-windows-amd64.exe"
        where curl >nul 2>&1
        if errorlevel 1 (
            echo        ERROR: curl no disponible. Instala jq manualmente.
            echo        URL: !JQ_URL!
        ) else (
            curl -sSLo "%OMNI_HOME%\bin\jq.exe" "!JQ_URL!" 2>nul
            if exist "%OMNI_HOME%\bin\jq.exe" (
                set "PATH=%OMNI_HOME%\bin;%PATH%"
                echo        [OK] jq descargado
            ) else (
                echo        [!!] descarga fallo - los hooks no funcionaran
            )
        )
    )
) else (
    echo   [OK] jq
)

REM ── PASO 2: Qwen Code CLI ──
echo.
echo [2/11] Qwen Code CLI...
if "%SKIP_CLI%"=="1" (
    echo   [--] Saltado ^(/SKIP_CLI^)
) else (
    where qwen >nul 2>&1
    if errorlevel 1 (
        echo   Instalando @qwen-code/qwen-code...
        call npm install -g @qwen-code/qwen-code@latest
        echo   [OK] Instalado
    ) else (
        echo   [OK] Ya instalado
    )
)

REM Patch de branding (PowerShell opcional)
if exist "%SCRIPT_DIR%patch-branding.ps1" (
    where powershell >nul 2>&1
    if not errorlevel 1 (
        powershell -ExecutionPolicy Bypass -NoProfile -File "%SCRIPT_DIR%patch-branding.ps1" >nul 2>&1
    )
)

REM ── PASO 3: Detectar repo ──
echo.
echo [3/11] Detectando archivos del repo...
if not exist "%REPO_DIR%\agents" (
    echo   ERROR: No se encontro agents\ en %REPO_DIR%
    endlocal & exit /b 2
)
if not exist "%REPO_DIR%\hooks" (
    echo   ERROR: No se encontro hooks\ en %REPO_DIR%
    endlocal & exit /b 2
)
echo   [OK] Repo detectado en %REPO_DIR%

REM ── Backup automatico antes de sobreescribir ──
if exist "%OMNI_HOME%\settings.json" (
    echo.
    set "BACKUP_TS=%DATE:/=-%_%TIME::=-%"
    set "BACKUP_TS=!BACKUP_TS: =0!"
    set "BACKUP_DIR=%OMNI_HOME%\.backups\pre-install-!BACKUP_TS!"
    echo [backup] %OMNI_HOME%\settings.json -^> !BACKUP_DIR!
    if not exist "%OMNI_HOME%\.backups" mkdir "%OMNI_HOME%\.backups"
    mkdir "!BACKUP_DIR!" 2>nul
    copy /y "%OMNI_HOME%\settings.json" "!BACKUP_DIR!\settings.json" >nul 2>&1
    if exist "%OMNI_HOME%\memory" (
        xcopy /e /i /y /q "%OMNI_HOME%\memory" "!BACKUP_DIR!\memory" >nul 2>&1
    )
)

REM ── PASO 4: Instalar Agentes ──
echo.
echo [4/11] Instalando agentes...
if not exist "%OMNI_HOME%\agents" mkdir "%OMNI_HOME%\agents"
set "AC=0"
for %%f in ("%REPO_DIR%\agents\*.md") do (
    copy /y "%%f" "%OMNI_HOME%\agents\%%~nxf" >nul
    if errorlevel 1 ( echo   ERROR copiando %%~nxf & endlocal & exit /b 3 )
    set /a AC+=1
)
echo   [OK] !AC! agentes -^> %%USERPROFILE%%\.omnicoder\agents\

REM ── PASO 5: Instalar Skills ──
echo.
echo [5/11] Instalando skills...
if not exist "%OMNI_HOME%\skills" mkdir "%OMNI_HOME%\skills"
set "SC=0"
REM v4.3.3 FIX: usar robocopy con /R:0 /W:0 (cero reintentos, zero wait).
REM Antes xcopy fallaba con rc=4 en skills con subdirs vacios (ui-ux-pro-max
REM tiene data/ y scripts/ vacios). Y robocopy default hace 1M retries x 30s
REM wait = cuelga el CI. Con /R:0 /W:0 es rapido y tolerante.
REM robocopy exit codes: 0-7 = success (0=no files, 1=copied, 3=copied+extras),
REM >=8 = error real.
for /d %%d in ("%REPO_DIR%\skills\*") do (
    robocopy "%%d" "%OMNI_HOME%\skills\%%~nxd" /E /R:0 /W:0 /NFL /NDL /NJH /NJS /NP /NC /NS >nul 2>&1
    if !errorlevel! GEQ 8 ( echo   ERROR copiando skill %%~nxd ^(robocopy rc=!errorlevel!^) & endlocal & exit /b 3 )
    set /a SC+=1
)
echo   [OK] !SC! skills -^> %%USERPROFILE%%\.omnicoder\skills\

REM ── PASO 6: Instalar Hooks ──
echo.
echo [6/11] Instalando hooks...
if not exist "%OMNI_HOME%\hooks" mkdir "%OMNI_HOME%\hooks"
set "HC=0"
for %%f in ("%REPO_DIR%\hooks\*.sh") do (
    copy /y "%%f" "%OMNI_HOME%\hooks\%%~nxf" >nul
    if errorlevel 1 ( echo   ERROR copiando hook %%~nxf & endlocal & exit /b 3 )
    set /a HC+=1
)
echo   [OK] !HC! hooks -^> %%USERPROFILE%%\.omnicoder\hooks\

REM ── PASO 7: Instalar Commands ──
echo.
echo [7/11] Instalando slash commands...
if not exist "%OMNI_HOME%\commands" mkdir "%OMNI_HOME%\commands"
set "CC=0"
for %%f in ("%REPO_DIR%\commands\*.md") do (
    copy /y "%%f" "%OMNI_HOME%\commands\%%~nxf" >nul
    set /a CC+=1
)
echo   [OK] !CC! commands -^> %%USERPROFILE%%\.omnicoder\commands\

REM ── PASO 8: Config + CLI wrappers ──
echo.
echo [8/11] Configurando...

REM OMNICODER.md
if exist "%REPO_DIR%\OMNICODER.md" (
    copy /y "%REPO_DIR%\OMNICODER.md" "%OMNI_HOME%\OMNICODER.md" >nul
    echo   [OK] OMNICODER.md
)

REM settings.json para OmniCoder + qwen (qwen lee hardcoded de .qwen\)
REM NOTA: los hooks usan "bash ~/.omnicoder/hooks/xxx.sh". Git Bash resuelve
REM       ~ a %USERPROFILE% automaticamente, asi que el mismo JSON funciona
REM       en Linux, macOS y Windows sin reescribir paths.
if exist "%REPO_DIR%\config\settings.json" (
    copy /y "%REPO_DIR%\config\settings.json" "%OMNI_HOME%\settings.json" >nul
    echo   [OK] settings.json -^> ~/.omnicoder/
    if not exist "%QWEN_HOME%" mkdir "%QWEN_HOME%"
    copy /y "%REPO_DIR%\config\settings.json" "%QWEN_HOME%\settings.json" >nul
    echo   [OK] settings.json -^> ~/.qwen/ ^(qwen CLI lo lee de ahi^)
    REM v4.3.1 FIX: limpiar TODOS los caches de OAuth residuales que causaban
    REM que qwen siguiera pidiendo auth aunque el usuario configurara API key.
    if exist "%QWEN_HOME%\oauth_creds.json" del /q "%QWEN_HOME%\oauth_creds.json"
    if exist "%QWEN_HOME%\access_token" del /q "%QWEN_HOME%\access_token"
    if exist "%QWEN_HOME%\refresh_token" del /q "%QWEN_HOME%\refresh_token"
    if exist "%QWEN_HOME%\.qwen_session" del /q "%QWEN_HOME%\.qwen_session"
    if exist "%QWEN_HOME%\auth.json" del /q "%QWEN_HOME%\auth.json"
)

REM Subdirs estandar
for %%D in (logs .cache bin) do (
    if not exist "%OMNI_HOME%\%%D" mkdir "%OMNI_HOME%\%%D"
)

REM CLI wrappers
if exist "%SCRIPT_DIR%omnicoder.cmd" (
    copy /y "%SCRIPT_DIR%omnicoder.cmd" "%OMNI_HOME%\omnicoder.cmd" >nul
    echo   [OK] omnicoder.cmd ^(CLI wrapper CMD^)
)
if exist "%SCRIPT_DIR%omnicoder.bat" (
    copy /y "%SCRIPT_DIR%omnicoder.bat" "%OMNI_HOME%\omnicoder.bat" >nul
)
if exist "%SCRIPT_DIR%omnicoder.ps1" (
    copy /y "%SCRIPT_DIR%omnicoder.ps1" "%OMNI_HOME%\omnicoder.ps1" >nul
    echo   [OK] omnicoder.ps1 ^(CLI wrapper PowerShell^)
)

REM Variable de entorno y PATH persistente (sesion actual + usuario)
REM v4.3.1 FIX: antes solo imprimia instrucciones y NO anadia el PATH. Ahora
REM usa PowerShell para leer SOLO el PATH de usuario (no mezclar con sistema),
REM detectar duplicados y persistir con SetEnvironmentVariable (no trunca).
setx OMNICODER_HOME "%OMNI_HOME%" >nul 2>&1
set "OMNICODER_HOME=%OMNI_HOME%"

where powershell >nul 2>&1
if errorlevel 1 (
    echo   [!!] PowerShell no disponible. Anade manualmente %OMNI_HOME% al PATH.
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "$u=[Environment]::GetEnvironmentVariable('Path','User'); if($u -eq $null){$u=''}; if($u -notlike '*%OMNI_HOME%*'){[Environment]::SetEnvironmentVariable('Path',($u.TrimEnd(';')+';%OMNI_HOME%').TrimStart(';'),'User'); Write-Host '  [OK] PATH de usuario actualizado (reinicia terminal para aplicar)'} else { Write-Host '  [OK] PATH ya contiene OmniCoder' }"
)
REM Actualizar sesion actual tambien
echo %PATH% | findstr /i ".omnicoder" >nul
if errorlevel 1 set "PATH=%PATH%;%OMNI_HOME%"

REM ── PASO 9: Memoria persistente ──
echo.
echo [9/11] Instalando memoria persistente...
if not exist "%OMNI_HOME%\memory" mkdir "%OMNI_HOME%\memory"
set "MC=0"
if exist "%REPO_DIR%\memory" (
    for %%f in ("%REPO_DIR%\memory\*.md") do (
        if "%FORCE%"=="1" (
            copy /y "%%f" "%OMNI_HOME%\memory\%%~nxf" >nul
            set /a MC+=1
        ) else if not exist "%OMNI_HOME%\memory\%%~nxf" (
            copy /y "%%f" "%OMNI_HOME%\memory\%%~nxf" >nul
            set /a MC+=1
        )
    )
    echo   [OK] !MC! archivos de memoria
) else (
    echo   [OK] Directorio de memoria creado
)

REM ── PASO 10: Construir indice de skills ──
echo.
echo [10/11] Construyendo indice de skills...
where bash >nul 2>&1
if errorlevel 1 (
    echo   [!!] bash no encontrado - indice se construira en primera ejecucion
) else (
    bash "%REPO_DIR%\scripts\build-skill-index.sh" >nul 2>&1
    if errorlevel 1 (
        echo   [!!] build-skill-index.sh fallo - revisar manualmente
    ) else (
        echo   [OK] Indice construido
    )
)

REM ── PASO 11: Setup provider ──
echo.
echo [11/11] Setup de provider (API key)...
if exist "%OMNI_HOME%\.env" (
    echo   [!!] Ya existe %OMNI_HOME%\.env
    echo        Para cambiar: powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%setup-provider.ps1"
) else (
    if "%FORCE%"=="1" (
        set "SETUPNOW=n"
    ) else (
        set /p "SETUPNOW=  Configurar API key ahora? [Y/n]: "
    )
    if /i not "!SETUPNOW!"=="n" (
        if exist "%SCRIPT_DIR%setup-provider.ps1" (
            powershell -ExecutionPolicy Bypass -NoProfile -File "%SCRIPT_DIR%setup-provider.ps1"
        ) else (
            echo   [!!] setup-provider.ps1 no encontrado
        )
    ) else (
        echo   Saltado. Cuando quieras:
        echo     powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%setup-provider.ps1"
    )
)

REM ── Guardar marker de version ──
> "%OMNI_HOME%\.version" echo %VERSION%

REM ── Resumen ──
echo.
echo ========================================================
echo           INSTALACION COMPLETADA v%VERSION%
echo ========================================================
echo.
echo   Agentes:  !AC!    Skills:  !SC!
echo   Hooks:    !HC!    Commands: !CC!
echo.
echo   PARA EMPEZAR:
echo     omnicoder               Iniciar OmniCoder ^(desde nueva terminal^)
echo     qwen                    Alternativa directa
echo     /agents manage          Ver agentes
echo     /skills                 Ver skills
echo     /review                 Code review
echo     /ship                   Test+lint+commit+push
echo     /handoff                Guardar progreso
echo.
echo   Diagnostico:   install-windows.bat /DOCTOR
echo   Cambiar API:   setup-provider.ps1
echo.
endlocal & exit /b 0


REM ============================================================
:show_help
echo.
echo OmniCoder Windows Installer v%VERSION%
echo.
echo Uso: install-windows.bat [/SKIP_CLI] [/FORCE] [/DOCTOR] [/HELP]
echo.
echo   /SKIP_CLI   No reinstalar qwen CLI
echo   /FORCE      Sobreescribir todo ^(incluye memoria^) sin preguntar
echo   /DOCTOR     Solo diagnostico, no instala
echo   /HELP       Esta ayuda
echo.
echo Alternativa: los flags tambien aceptan formato --skip-cli, --force, --doctor, --help
echo.
endlocal & exit /b 0


REM ============================================================
:doctor
echo === OmniCoder - Doctor (Windows) ===
echo.
set "ISSUES=0"

where node >nul 2>&1
if errorlevel 1 (
    echo   [!!] Node.js no instalado
    set /a ISSUES+=1
) else (
    for /f "tokens=* usebackq" %%a in (`node -v`) do echo   [OK] Node.js %%a
)

where npm >nul 2>&1
if errorlevel 1 ( echo   [!!] npm no instalado & set /a ISSUES+=1 ) else echo   [OK] npm

where git >nul 2>&1
if errorlevel 1 ( echo   [!!] git no instalado & set /a ISSUES+=1 ) else echo   [OK] git

where bash >nul 2>&1
if errorlevel 1 ( echo   [!!] bash no instalado ^(Git Bash o WSL^) & set /a ISSUES+=1 ) else echo   [OK] bash

where jq >nul 2>&1
if errorlevel 1 (
    if exist "%OMNI_HOME%\bin\jq.exe" ( echo   [OK] jq ^(local^) ) else ( echo   [!!] jq no instalado & set /a ISSUES+=1 )
) else echo   [OK] jq

where qwen >nul 2>&1
if errorlevel 1 ( echo   [!!] qwen CLI no instalado & set /a ISSUES+=1 ) else echo   [OK] qwen CLI

if exist "%OMNI_HOME%\.version" (
    set /p VER=<"%OMNI_HOME%\.version"
    echo   [OK] OmniCoder v!VER! instalado en %OMNI_HOME%
) else (
    echo   [!!] OmniCoder no instalado
    set /a ISSUES+=1
)

if exist "%OMNI_HOME%\settings.json" ( echo   [OK] settings.json ) else ( echo   [!!] settings.json faltante & set /a ISSUES+=1 )

set "AGENT_COUNT=0"
if exist "%OMNI_HOME%\agents" (
    for %%f in ("%OMNI_HOME%\agents\*.md") do set /a AGENT_COUNT+=1
    if !AGENT_COUNT! GEQ 100 ( echo   [OK] !AGENT_COUNT! agentes ) else ( echo   [!!] Solo !AGENT_COUNT! agentes & set /a ISSUES+=1 )
)

set "HOOK_COUNT=0"
if exist "%OMNI_HOME%\hooks" (
    for %%f in ("%OMNI_HOME%\hooks\*.sh") do set /a HOOK_COUNT+=1
    if !HOOK_COUNT! GEQ 16 ( echo   [OK] !HOOK_COUNT! hooks ) else ( echo   [!!] Solo !HOOK_COUNT! hooks & set /a ISSUES+=1 )
)

if exist "%OMNI_HOME%\.env" ( echo   [OK] Provider configurado ) else ( echo   [!!] Sin provider configurado & set /a ISSUES+=1 )

echo.
if "!ISSUES!"=="0" (
    echo   Todo OK - OmniCoder funcionando
    endlocal & exit /b 0
) else (
    echo   !ISSUES! issues encontrados
    echo   Repara con: install-windows.bat /FORCE
    endlocal & exit /b 1
)
