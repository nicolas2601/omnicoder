# ============================================================
# OmniCoder v4.2 - Instalador para Windows (PowerShell)
# 168 agentes + 193 skills + 18 hooks + 21 commands + settings
# ============================================================
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "    OMNICODER v4.2.0 - INSTALADOR WINDOWS                  " -ForegroundColor Cyan
Write-Host "    168 Agentes + 193 Skills + 18 Hooks + 21 Commands    " -ForegroundColor Cyan
Write-Host "    Multi-provider | Cognitive routing | Subagent verify " -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir = Split-Path -Parent $ScriptDir

# ── Upgrade detection ──
$VersionFile = Join-Path $env:USERPROFILE '.omnicoder\.version'
$LegacyDir = Join-Path $env:USERPROFILE '.qwen\agents'
$CurrentVersion = "4.2.0"

if (Test-Path $VersionFile) {
    $InstalledVer = (Get-Content $VersionFile -Raw).Trim()
    Write-Host "  Version instalada: $InstalledVer" -ForegroundColor Yellow
    Write-Host "  Version nueva:     $CurrentVersion" -ForegroundColor Green
    if ($InstalledVer -eq $CurrentVersion) {
        Write-Host "  Ya tienes la version actual. Reinstala con -Force." -ForegroundColor Green
        exit 0
    }
    $confirm = Read-Host "  Actualizar? [Y/n]"
    if ($confirm -eq 'n') { exit 0 }
} elseif (Test-Path $LegacyDir) {
    Write-Host "  Legacy detectado: Qwen Con Poderes en $env:USERPROFILE\.qwen\" -ForegroundColor Yellow
    Write-Host "  OmniCoder v$CurrentVersion se instalara en $env:USERPROFILE\.omnicoder\" -ForegroundColor Green
    $confirm = Read-Host "  Continuar? [Y/n]"
    if ($confirm -eq 'n') { exit 0 }
}

# ── PASO 1: Requisitos ──
Write-Host "[1/11] Verificando requisitos..." -ForegroundColor Blue
try {
    $nv = (node -v) -replace 'v', ''
    if ([int]($nv.Split('.')[0]) -lt 20) { Write-Host "  ERROR: Node.js v20+ requerido" -ForegroundColor Red; exit 1 }
    Write-Host "  [OK] Node.js v$nv" -ForegroundColor Green
} catch { Write-Host "  ERROR: Node.js no instalado. winget install OpenJS.NodeJS.LTS" -ForegroundColor Red; exit 1 }

try { $null = npm -v; Write-Host "  [OK] npm" -ForegroundColor Green } catch { Write-Host "  ERROR: npm no instalado" -ForegroundColor Red; exit 1 }
try { $null = git --version; Write-Host "  [OK] git" -ForegroundColor Green } catch { Write-Host "  ERROR: git no instalado" -ForegroundColor Red; exit 1 }

# ── PASO 2: Qwen CLI ──
Write-Host "`n[2/11] Qwen Code CLI..." -ForegroundColor Blue
try { $null = Get-Command qwen -ErrorAction Stop; Write-Host "  [OK] Ya instalado" -ForegroundColor Green }
catch { npm install -g @qwen-code/qwen-code@latest; Write-Host "  [OK] Instalado" -ForegroundColor Green }

# ── PASO 3: Verificar repo ──
Write-Host "`n[3/11] Verificando repo..." -ForegroundColor Blue
if (-not (Test-Path "$RepoDir\agents")) { Write-Host "  ERROR: agents\ no encontrado" -ForegroundColor Red; exit 1 }
Write-Host "  [OK] Repo detectado" -ForegroundColor Green

# ── PASO 4: Agentes ──
Write-Host "`n[4/11] Instalando agentes..." -ForegroundColor Blue
$AgentsDir = "$env:USERPROFILE\.omnicoder\agents"
New-Item -ItemType Directory -Path $AgentsDir -Force | Out-Null
$ac = 0; Get-ChildItem "$RepoDir\agents\*.md" | ForEach-Object { Copy-Item $_.FullName "$AgentsDir\$($_.Name)" -Force; $ac++ }
Write-Host "  [OK] $ac agentes" -ForegroundColor Green

# ── PASO 5: Skills ──
Write-Host "`n[5/11] Instalando skills..." -ForegroundColor Blue
$SkillsDir = "$env:USERPROFILE\.omnicoder\skills"
New-Item -ItemType Directory -Path $SkillsDir -Force | Out-Null
$sc = 0; Get-ChildItem "$RepoDir\skills" -Directory | ForEach-Object { Copy-Item $_.FullName "$SkillsDir\$($_.Name)" -Recurse -Force; $sc++ }
Write-Host "  [OK] $sc skills" -ForegroundColor Green

# ── PASO 6: Hooks ──
Write-Host "`n[6/11] Instalando hooks..." -ForegroundColor Blue
$HooksDir = "$env:USERPROFILE\.omnicoder\hooks"
New-Item -ItemType Directory -Path $HooksDir -Force | Out-Null
$hc = 0; Get-ChildItem "$RepoDir\hooks\*.sh" | ForEach-Object { Copy-Item $_.FullName "$HooksDir\$($_.Name)" -Force; $hc++ }
Write-Host "  [OK] $hc hooks" -ForegroundColor Green

# ── PASO 7: Commands ──
Write-Host "`n[7/11] Instalando commands..." -ForegroundColor Blue
$CmdsDir = "$env:USERPROFILE\.omnicoder\commands"
New-Item -ItemType Directory -Path $CmdsDir -Force | Out-Null
$cc = 0; Get-ChildItem "$RepoDir\commands\*.md" | ForEach-Object { Copy-Item $_.FullName "$CmdsDir\$($_.Name)" -Force; $cc++ }
Write-Host "  [OK] $cc commands" -ForegroundColor Green

# ── PASO 8: Config ──
Write-Host "`n[8/11] Configurando..." -ForegroundColor Blue
if (Test-Path "$RepoDir\OMNICODER.md") { Copy-Item "$RepoDir\OMNICODER.md" "$env:USERPROFILE\.omnicoder\OMNICODER.md" -Force; Write-Host "  [OK] OMNICODER.md" -ForegroundColor Green }
if (Test-Path "$RepoDir\config\settings.json") { Copy-Item "$RepoDir\config\settings.json" "$env:USERPROFILE\.omnicoder\settings.json" -Force; Write-Host "  [OK] settings.json" -ForegroundColor Green }
New-Item -ItemType Directory -Path "$env:USERPROFILE\.omnicoder\logs" -Force | Out-Null

# Instalar CLI wrappers (omnicoder.bat y omnicoder.ps1)
$wrapperBat = Join-Path $RepoDir 'scripts\omnicoder.bat'
$wrapperPs1 = Join-Path $RepoDir 'scripts\omnicoder.ps1'
if (Test-Path $wrapperBat) {
    Copy-Item $wrapperBat "$env:USERPROFILE\.omnicoder\omnicoder.bat" -Force
    Write-Host "  [OK] omnicoder.bat (CLI wrapper)" -ForegroundColor Green
}
if (Test-Path $wrapperPs1) {
    Copy-Item $wrapperPs1 "$env:USERPROFILE\.omnicoder\omnicoder.ps1" -Force
    Write-Host "  [OK] omnicoder.ps1 (CLI wrapper)" -ForegroundColor Green
}

# Verificar si ~/.omnicoder esta en PATH, sugerir agregarlo
$omniPath = "$env:USERPROFILE\.omnicoder"
if ($env:PATH -notlike "*$omniPath*") {
    Write-Host ""
    Write-Host "  [!!] Para usar 'omnicoder' desde cualquier terminal, agrega al PATH:" -ForegroundColor Yellow
    Write-Host "       [Environment]::SetEnvironmentVariable('Path', `$env:Path + ';$omniPath', 'User')" -ForegroundColor DarkGray
}

# ── PASO 9: Memoria persistente ──
Write-Host "`n[9/11] Instalando memoria persistente..." -ForegroundColor Blue
$MemDir = "$env:USERPROFILE\.omnicoder\memory"
New-Item -ItemType Directory -Path $MemDir -Force | Out-Null
if (Test-Path "$RepoDir\memory") {
    $mc = 0; Get-ChildItem "$RepoDir\memory\*.md" -ErrorAction SilentlyContinue | ForEach-Object {
        $dest = Join-Path $MemDir $_.Name
        if (-not (Test-Path $dest)) { Copy-Item $_.FullName $dest -Force; $mc++ }
    }
    Write-Host "  [OK] $mc archivos de memoria" -ForegroundColor Green
}

# ── PASO 10: Build skill index ──
Write-Host "`n[10/11] Construyendo indice de skills..." -ForegroundColor Blue
try {
    $bashPath = Get-Command bash -ErrorAction Stop
    & bash "$RepoDir\scripts\build-skill-index.sh" 2>$null
    Write-Host "  [OK] Indice construido" -ForegroundColor Green
} catch {
    Write-Host "  [!!] bash no disponible - indice se construira en primera ejecucion" -ForegroundColor Yellow
}

# ── PASO 11: Setup de provider (API key) ──
Write-Host "`n[11/11] Setup de provider (API key)..." -ForegroundColor Blue
$activeEnv = "$env:USERPROFILE\.omnicoder\.env"
if (Test-Path $activeEnv) {
    Write-Host "  [!!] Ya existe ~/.omnicoder/.env (provider configurado)" -ForegroundColor Yellow
    Write-Host "       Para cambiar: powershell -ExecutionPolicy Bypass -File scripts\setup-provider.ps1"
} else {
    $setupNow = Read-Host "  Configurar API key ahora? [Y/n]"
    if ($setupNow.ToLower() -ne 'n') {
        $setupScript = Join-Path $ScriptDir 'setup-provider.ps1'
        if (Test-Path $setupScript) {
            & $setupScript
        } else {
            Write-Host "  [!!] setup-provider.ps1 no encontrado en $setupScript" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  Saltado. Cuando quieras: powershell -ExecutionPolicy Bypass -File scripts\setup-provider.ps1"
    }
}

# ── Save version marker ──
$CurrentVersion | Set-Content $VersionFile

# ── Resumen ──
Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "           INSTALACION COMPLETADA v4.2.0                  " -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host "`n  Agentes: $ac | Skills: $sc | Hooks: $hc | Commands: $cc"
if (Test-Path $activeEnv) {
    $model = (Get-Content $activeEnv | Where-Object { $_ -match '^OPENAI_MODEL=' }) -replace 'OPENAI_MODEL=',''
    Write-Host "  Provider activo: $model" -ForegroundColor Cyan
} else {
    Write-Host "  Provider: NO configurado -> setup-provider.ps1" -ForegroundColor Red
}
Write-Host "`n  PARA EMPEZAR:" -ForegroundColor Yellow
Write-Host "    qwen                   Iniciar OmniCoder"
Write-Host "    /agents manage         Ver agentes"
Write-Host "    /skills                Ver skills"
Write-Host "    /review                Code review"
Write-Host "    /ship                  Test+lint+commit+push"
Write-Host "    /audit                 Auditoria completa"
Write-Host "    /handoff               Guardar progreso"
Write-Host "    /verify-last           Auditoria del ultimo subagent"
Write-Host "`n  Cambiar provider: bash scripts\switch-provider.sh nvidia|gemini|..."
Write-Host ""
