#Requires -Version 5.1
<#
.SYNOPSIS
    OmniCoder v4.3 - Instalador para Windows (PowerShell)
.DESCRIPTION
    Paridad con install-linux.sh e install-windows.bat.
    Soporta PowerShell 5.1+ y PowerShell 7+ (pwsh).
.PARAMETER SkipCli
    No reinstala el qwen CLI
.PARAMETER Force
    Sobreescribe todo (incluye memoria) sin preguntar
.PARAMETER Doctor
    Solo diagnostico, no instala
.PARAMETER Update
    Alias de -Force para actualizacion
.EXAMPLE
    .\install-windows.ps1
    .\install-windows.ps1 -Force -SkipCli
    .\install-windows.ps1 -Doctor
#>
[CmdletBinding()]
param(
    [switch]$SkipCli,
    [switch]$Force,
    [switch]$Doctor,
    [switch]$Update
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

if ($Update) { $Force = $true }

$Version = '4.3.0'
$OmniHome = Join-Path $env:USERPROFILE '.omnicoder'
$QwenHome = Join-Path $env:USERPROFILE '.qwen'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir = Split-Path -Parent $ScriptDir

# ─────────────────────── Helpers ───────────────────────
function Write-Banner {
    Write-Host ''
    Write-Host '========================================================' -ForegroundColor Cyan
    Write-Host ('   OMNICODER v{0} - INSTALADOR WINDOWS (PS)' -f $Version) -ForegroundColor Cyan
    Write-Host '   168 Agentes + 193 Skills + 18 Hooks + 21 Commands   ' -ForegroundColor Cyan
    Write-Host '   Multi-provider | Cognitive routing | Subagent verify' -ForegroundColor Cyan
    Write-Host '========================================================' -ForegroundColor Cyan
    Write-Host ''
}

function Write-Step([string]$Label, [string]$Message) {
    Write-Host ('[{0}] {1}' -f $Label, $Message) -ForegroundColor Blue
}

function Write-Ok([string]$Message)    { Write-Host "  [OK] $Message" -ForegroundColor Green }
function Write-Warn2([string]$Message) { Write-Host "  [!!] $Message" -ForegroundColor Yellow }
function Write-Err([string]$Message)   { Write-Host "  ERROR: $Message" -ForegroundColor Red }

function Test-Prereq {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$InstallHint = '',
        [switch]$Optional
    )
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -eq $cmd) {
        if ($Optional) {
            Write-Warn2 "$Name no instalado. $InstallHint"
            return $false
        }
        Write-Err "$Name no instalado. $InstallHint"
        return $false
    }
    Write-Ok $Name
    return $true
}

function Ensure-Dir([string]$Path) {
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Copy-Files {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][string]$Filter,
        [switch]$Recurse
    )
    Ensure-Dir $Destination
    $count = 0
    if ($Recurse) {
        Get-ChildItem -Path $Source -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination (Join-Path $Destination $_.Name) -Recurse -Force
            $count++
        }
    } else {
        Get-ChildItem -Path $Source -Filter $Filter -File -ErrorAction SilentlyContinue | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination (Join-Path $Destination $_.Name) -Force
            $count++
        }
    }
    return $count
}

# ─────────────────────── Doctor ───────────────────────
function Invoke-Doctor {
    Write-Host '=== OmniCoder - Doctor (Windows) ===' -ForegroundColor Blue
    Write-Host ''
    $issues = 0

    $node = Get-Command node -ErrorAction SilentlyContinue
    if ($node) {
        $v = (& node -v) -replace '^v',''
        $major = [int]($v.Split('.')[0])
        if ($major -ge 20) { Write-Ok ("Node.js v{0}" -f $v) }
        else { Write-Warn2 ("Node.js v{0} - requiere v20+" -f $v); $issues++ }
    } else { Write-Warn2 'Node.js no instalado'; $issues++ }

    foreach ($p in @('npm','git','bash','jq','qwen')) {
        if (-not (Get-Command $p -ErrorAction SilentlyContinue)) {
            if ($p -eq 'jq' -and (Test-Path (Join-Path $OmniHome 'bin\jq.exe'))) {
                Write-Ok 'jq (local)'
            } else {
                Write-Warn2 "$p no instalado"; $issues++
            }
        } else { Write-Ok $p }
    }

    $verFile = Join-Path $OmniHome '.version'
    if (Test-Path $verFile) {
        $ver = (Get-Content $verFile -Raw).Trim()
        Write-Ok ("OmniCoder v{0} instalado" -f $ver)
    } else { Write-Warn2 'OmniCoder no instalado'; $issues++ }

    if (Test-Path (Join-Path $OmniHome 'settings.json')) { Write-Ok 'settings.json' }
    else { Write-Warn2 'settings.json faltante'; $issues++ }

    $agents = (Get-ChildItem (Join-Path $OmniHome 'agents\*.md') -ErrorAction SilentlyContinue).Count
    if ($agents -ge 100) { Write-Ok "$agents agentes" }
    else { Write-Warn2 "Solo $agents agentes"; $issues++ }

    $hooks = (Get-ChildItem (Join-Path $OmniHome 'hooks\*.sh') -ErrorAction SilentlyContinue).Count
    if ($hooks -ge 16) { Write-Ok "$hooks hooks" }
    else { Write-Warn2 "Solo $hooks hooks"; $issues++ }

    if (Test-Path (Join-Path $OmniHome '.env')) { Write-Ok 'Provider configurado' }
    else { Write-Warn2 'Sin provider configurado'; $issues++ }

    Write-Host ''
    if ($issues -eq 0) {
        Write-Host '  Todo OK - OmniCoder funcionando' -ForegroundColor Green
        exit 0
    } else {
        Write-Host "  $issues issues encontrados" -ForegroundColor Yellow
        Write-Host '  Repara con: .\install-windows.ps1 -Force' -ForegroundColor DarkGray
        exit 1
    }
}

# ─────────────────────── Main ───────────────────────
Write-Banner
if ($Doctor) { Invoke-Doctor }

# Upgrade detection
$verFile = Join-Path $OmniHome '.version'
$legacyDir = Join-Path $QwenHome 'agents'

if (Test-Path $verFile) {
    $installed = (Get-Content $verFile -Raw).Trim()
    Write-Host "  Version instalada: $installed" -ForegroundColor Yellow
    Write-Host "  Version nueva:     $Version" -ForegroundColor Green
    if ($installed -eq $Version -and -not $Force) {
        Write-Host '  Ya tienes la version actual. Usa -Force para reinstalar.' -ForegroundColor Green
        exit 0
    }
    if (-not $Force) {
        $confirm = Read-Host '  Actualizar? [Y/n]'
        if ($confirm -match '^[nN]') { Write-Host 'Cancelado.' -ForegroundColor Red; exit 0 }
    }
} elseif (Test-Path $legacyDir) {
    Write-Warn2 ("Legacy (OmniCoder pre-rebrand) detectado en {0}" -f $QwenHome)
    Write-Host ("  OmniCoder v{0} se instalara en {1}" -f $Version, $OmniHome) -ForegroundColor Green
    Write-Host '  Tu memoria en .qwen\memory NO se eliminara.' -ForegroundColor DarkGray
    if (-not $Force) {
        $confirm = Read-Host '  Continuar? [Y/n]'
        if ($confirm -match '^[nN]') { exit 0 }
    }
}
Write-Host ''

# PASO 1: Requisitos
Write-Step '1/11' 'Verificando requisitos...'
$nodeOk = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeOk) { Write-Err 'Node.js no instalado. winget install OpenJS.NodeJS.LTS'; exit 1 }
$nodeVer = (& node -v) -replace '^v',''
$nodeMajor = [int]($nodeVer.Split('.')[0])
if ($nodeMajor -lt 20) { Write-Err "Node.js v20+ requerido (actual: v$nodeVer)"; exit 1 }
Write-Ok "Node.js v$nodeVer"

if (-not (Test-Prereq 'npm' 'Reinstala Node.js LTS')) { exit 1 }
if (-not (Test-Prereq 'git' 'winget install Git.Git')) { exit 1 }

$bashOk = Get-Command bash -ErrorAction SilentlyContinue
if (-not $bashOk) {
    Write-Warn2 'bash no en PATH - los hooks NO funcionaran'
    Write-Host '       Instala Git for Windows: https://git-scm.com/download/win' -ForegroundColor DarkGray
    if (-not $Force) {
        $ok = Read-Host '  Continuar sin bash? [y/N]'
        if ($ok -notmatch '^[yY]') { exit 1 }
    }
} else { Write-Ok 'bash' }

# jq (local download si falta)
Ensure-Dir (Join-Path $OmniHome 'bin')
$jqOk = Get-Command jq -ErrorAction SilentlyContinue
$jqLocal = Join-Path $OmniHome 'bin\jq.exe'
if (-not $jqOk) {
    if (Test-Path $jqLocal) {
        $env:PATH = "$OmniHome\bin;$env:PATH"
        Write-Ok ("jq (local en {0})" -f $jqLocal)
    } else {
        Write-Warn2 'jq no instalado - descargando...'
        try {
            $url = 'https://github.com/jqlang/jq/releases/latest/download/jq-windows-amd64.exe'
            Invoke-WebRequest -Uri $url -OutFile $jqLocal -UseBasicParsing -TimeoutSec 30
            $env:PATH = "$OmniHome\bin;$env:PATH"
            Write-Ok 'jq descargado'
        } catch {
            Write-Warn2 ("Descarga fallo: {0}" -f $_.Exception.Message)
        }
    }
} else { Write-Ok 'jq' }

# PASO 2: Qwen CLI
Write-Host ''
Write-Step '2/11' 'Qwen Code CLI...'
if ($SkipCli) {
    Write-Host '  [--] Saltado (-SkipCli)' -ForegroundColor DarkGray
} elseif (Get-Command qwen -ErrorAction SilentlyContinue) {
    Write-Ok 'Ya instalado'
} else {
    Write-Host '  Instalando @qwen-code/qwen-code...' -ForegroundColor DarkGray
    npm install -g '@qwen-code/qwen-code@latest'
    Write-Ok 'Instalado'
}

$patch = Join-Path $ScriptDir 'patch-branding.ps1'
if (Test-Path $patch) {
    try { & $patch | Out-Null } catch { Write-Warn2 "patch-branding fallo: $($_.Exception.Message)" }
} else {
    Write-Warn2 'patch-branding.ps1 no encontrado'
}

# PASO 3: Detectar repo
Write-Host ''
Write-Step '3/11' 'Detectando archivos del repo...'
if (-not (Test-Path (Join-Path $RepoDir 'agents'))) { Write-Err "agents\ no encontrado en $RepoDir"; exit 2 }
if (-not (Test-Path (Join-Path $RepoDir 'hooks')))  { Write-Err "hooks\ no encontrado en $RepoDir"; exit 2 }
Write-Ok "Repo en $RepoDir"

# Backup pre-install
if (Test-Path (Join-Path $OmniHome 'settings.json')) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupDir = Join-Path $OmniHome (".backups\pre-install-$stamp")
    Ensure-Dir $backupDir
    try {
        Copy-Item (Join-Path $OmniHome 'settings.json') $backupDir -Force
        if (Test-Path (Join-Path $OmniHome 'memory')) {
            Copy-Item (Join-Path $OmniHome 'memory') $backupDir -Recurse -Force
        }
        Write-Host "  [backup] settings + memory -> $backupDir" -ForegroundColor DarkGray
    } catch { Write-Warn2 "backup fallo: $($_.Exception.Message)" }
}

# PASO 4: Agentes
Write-Host ''
Write-Step '4/11' 'Instalando agentes...'
try {
    $ac = Copy-Files -Source (Join-Path $RepoDir 'agents') -Destination (Join-Path $OmniHome 'agents') -Filter '*.md'
    Write-Ok "$ac agentes"
} catch { Write-Err "Copia fallo: $($_.Exception.Message)"; exit 3 }

# PASO 5: Skills
Write-Host ''
Write-Step '5/11' 'Instalando skills...'
try {
    $sc = Copy-Files -Source (Join-Path $RepoDir 'skills') -Destination (Join-Path $OmniHome 'skills') -Filter '*' -Recurse
    Write-Ok "$sc skills"
} catch { Write-Err "Copia fallo: $($_.Exception.Message)"; exit 3 }

# PASO 6: Hooks
Write-Host ''
Write-Step '6/11' 'Instalando hooks...'
try {
    $hc = Copy-Files -Source (Join-Path $RepoDir 'hooks') -Destination (Join-Path $OmniHome 'hooks') -Filter '*.sh'
    Write-Ok "$hc hooks"
} catch { Write-Err "Copia fallo: $($_.Exception.Message)"; exit 3 }

# PASO 7: Commands
# v4.3.2 FIX: copiar tambien a ~/.qwen/commands/ (Qwen CLI los lee de ahi).
Write-Host ''
Write-Step '7/11' 'Instalando commands...'
try {
    $srcCmds = Join-Path $RepoDir 'commands'
    $cc = Copy-Files -Source $srcCmds -Destination (Join-Path $OmniHome 'commands') -Filter '*.md'
    Ensure-Dir (Join-Path $QwenHome 'commands')
    Copy-Files -Source $srcCmds -Destination (Join-Path $QwenHome 'commands') -Filter '*.md' | Out-Null
    Write-Ok "$cc commands -> .omnicoder\commands\ + .qwen\commands\"
} catch { Write-Err "Copia fallo: $($_.Exception.Message)"; exit 3 }

# PASO 8: Config + wrappers
Write-Host ''
Write-Step '8/11' 'Configurando...'
$omniMd = Join-Path $RepoDir 'OMNICODER.md'
if (Test-Path $omniMd) {
    Copy-Item $omniMd (Join-Path $OmniHome 'OMNICODER.md') -Force
    # v4.3.2 FIX: copiar tambien como QWEN.md (qwen CLI lo lee como system prompt).
    Ensure-Dir $QwenHome
    Copy-Item $omniMd (Join-Path $QwenHome 'QWEN.md') -Force
    Write-Ok 'OMNICODER.md -> ~/.omnicoder/ + ~/.qwen/QWEN.md'
}

# settings.json cross-platform: hooks usan "bash ~/.omnicoder/hooks/xxx.sh".
# Git Bash resuelve ~ a %USERPROFILE% automaticamente, asi que NO hace falta
# reescribir paths para Windows — el mismo JSON funciona en Linux/macOS/Windows.
$srcSettings = Join-Path $RepoDir 'config\settings.json'
if (Test-Path $srcSettings) {
    Copy-Item $srcSettings (Join-Path $OmniHome 'settings.json') -Force
    Write-Ok 'settings.json -> ~/.omnicoder/'
    Ensure-Dir $QwenHome
    Copy-Item $srcSettings (Join-Path $QwenHome 'settings.json') -Force
    Write-Ok 'settings.json -> ~/.qwen/ (qwen CLI lo lee de ahi)'
    # v4.3.1 FIX: limpiar TODOS los caches de OAuth residuales que causaban
    # que qwen siguiera pidiendo auth aunque hubiese API key.
    foreach ($f in @('oauth_creds.json','access_token','refresh_token','.qwen_session','auth.json')) {
        $path = Join-Path $QwenHome $f
        if (Test-Path $path) { Remove-Item $path -Force -ErrorAction SilentlyContinue }
    }
}

foreach ($d in @('logs','.cache','bin','scripts')) { Ensure-Dir (Join-Path $OmniHome $d) }

# v4.3.2: scripts runtime invocados por slash commands (personality, etc)
$rtScripts = @('personality.sh','_colors.sh','_spinner.sh','backup.sh','restore.sh')
foreach ($s in $rtScripts) {
    $src = Join-Path $ScriptDir $s
    if (Test-Path $src) { Copy-Item $src (Join-Path $OmniHome "scripts\$s") -Force }
}

# CLI wrappers
foreach ($w in @('omnicoder.cmd','omnicoder.bat','omnicoder.ps1')) {
    $src = Join-Path $ScriptDir $w
    if (Test-Path $src) {
        Copy-Item $src (Join-Path $OmniHome $w) -Force
        Write-Ok "$w"
    }
}

# OMNICODER_HOME env + PATH persistente (scope User)
try {
    [Environment]::SetEnvironmentVariable('OMNICODER_HOME', $OmniHome, 'User')
    $env:OMNICODER_HOME = $OmniHome
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not $userPath) { $userPath = '' }
    if ($userPath -notlike "*$OmniHome*") {
        $newPath = if ($userPath) { "$userPath;$OmniHome" } else { $OmniHome }
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        Write-Ok 'PATH actualizado (abre nueva terminal para aplicar)'
    } else {
        Write-Ok 'PATH ya contiene OmniCoder'
    }
    # v4.3.1 FIX: actualizar tambien la sesion actual para que el usuario
    # pueda usar `omnicoder` sin cerrar/abrir la terminal.
    if ($env:Path -notlike "*$OmniHome*") { $env:Path = "$($env:Path);$OmniHome" }
} catch {
    Write-Warn2 "No se pudo actualizar PATH: $($_.Exception.Message)"
    Write-Host "       Manual: [Environment]::SetEnvironmentVariable('Path', `$env:Path + ';$OmniHome', 'User')" -ForegroundColor DarkGray
}

# PASO 9: Memoria
Write-Host ''
Write-Step '9/11' 'Instalando memoria persistente...'
$memDir = Join-Path $OmniHome 'memory'
Ensure-Dir $memDir
$repoMem = Join-Path $RepoDir 'memory'
$mc = 0
if (Test-Path $repoMem) {
    Get-ChildItem (Join-Path $repoMem '*.md') -ErrorAction SilentlyContinue | ForEach-Object {
        $dest = Join-Path $memDir $_.Name
        if ($Force -or -not (Test-Path $dest)) {
            Copy-Item $_.FullName $dest -Force
            $mc++
        }
    }
    Write-Ok "$mc archivos de memoria"
} else {
    Write-Ok 'Directorio creado'
}

# PASO 10: Build skill index
Write-Host ''
Write-Step '10/11' 'Construyendo indice de skills...'
$bashOk = Get-Command bash -ErrorAction SilentlyContinue
if ($bashOk) {
    try {
        & bash (Join-Path $RepoDir 'scripts\build-skill-index.sh') 2>$null
        Write-Ok 'Indice construido'
    } catch {
        Write-Warn2 "build-skill-index.sh fallo: $($_.Exception.Message)"
    }
} else {
    Write-Warn2 'bash no disponible - indice se construira en primera ejecucion'
}

# PASO 11: Provider
Write-Host ''
Write-Step '11/11' 'Setup de provider (API key)...'
$envFile = Join-Path $OmniHome '.env'
if (Test-Path $envFile) {
    Write-Warn2 'Ya existe .env (provider configurado)'
    Write-Host '       Para cambiar: .\scripts\setup-provider.ps1' -ForegroundColor DarkGray
} else {
    if ($Force) { $setup = 'n' } else { $setup = Read-Host '  Configurar API key ahora? [Y/n]' }
    if ($setup -notmatch '^[nN]') {
        $setupScript = Join-Path $ScriptDir 'setup-provider.ps1'
        if (Test-Path $setupScript) {
            try { & $setupScript } catch { Write-Warn2 "setup-provider fallo: $($_.Exception.Message)" }
        } else { Write-Warn2 'setup-provider.ps1 no encontrado' }
    } else {
        Write-Host '  Saltado. Cuando quieras: .\scripts\setup-provider.ps1' -ForegroundColor DarkGray
    }
}

# Version marker
Set-Content -Path $verFile -Value $Version -Encoding ASCII

# Resumen
Write-Host ''
Write-Host '========================================================' -ForegroundColor Green
Write-Host ("           INSTALACION COMPLETADA v{0}" -f $Version)    -ForegroundColor Green
Write-Host '========================================================' -ForegroundColor Green
Write-Host ''
Write-Host ("  Agentes: {0} | Skills: {1} | Hooks: {2} | Commands: {3}" -f $ac, $sc, $hc, $cc)
if (Test-Path $envFile) {
    $model = (Get-Content $envFile | Where-Object { $_ -match '^OPENAI_MODEL=' }) -replace '^OPENAI_MODEL=',''
    Write-Host ("  Provider activo: {0}" -f $model) -ForegroundColor Cyan
} else {
    Write-Host '  Provider: NO configurado -> setup-provider.ps1' -ForegroundColor Red
}
Write-Host ''
Write-Host '  PARA EMPEZAR:' -ForegroundColor Yellow
Write-Host '    omnicoder               Iniciar OmniCoder (nueva terminal)'
Write-Host '    qwen                    Alternativa directa'
Write-Host '    /agents manage          Ver agentes'
Write-Host '    /skills                 Ver skills'
Write-Host '    /review                 Code review'
Write-Host '    /ship                   Test+lint+commit+push'
Write-Host '    /handoff                Guardar progreso'
Write-Host ''
Write-Host '  Diagnostico: .\install-windows.ps1 -Doctor' -ForegroundColor DarkGray
Write-Host ''
exit 0
