# ============================================================
# Qwen Con Poderes - Instalador para Windows (PowerShell)
# Instala Qwen Code CLI + 168 agentes + 193 skills
# ============================================================
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "         QWEN CON PODERES - INSTALADOR WINDOWS          " -ForegroundColor Cyan
Write-Host "    168 Agentes + 193 Skills para Qwen Code CLI          " -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

# ──────────────────────────────────────────────────────────
# PASO 1: Verificar requisitos
# ──────────────────────────────────────────────────────────
Write-Host "[1/5] Verificando requisitos..." -ForegroundColor Blue

# Node.js
try {
    $nodeVersion = (node -v) -replace 'v', ''
    $majorVersion = [int]($nodeVersion.Split('.')[0])
    if ($majorVersion -lt 20) {
        Write-Host "  ERROR: Node.js v20+ requerido. Tienes v$nodeVersion" -ForegroundColor Red
        Write-Host "  Instala desde: https://nodejs.org" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "  [OK] Node.js v$nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Node.js no esta instalado." -ForegroundColor Red
    Write-Host "  Instala con: winget install OpenJS.NodeJS.LTS" -ForegroundColor Yellow
    exit 1
}

# npm
try {
    $npmVersion = npm -v
    Write-Host "  [OK] npm v$npmVersion" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: npm no esta instalado." -ForegroundColor Red
    exit 1
}

# git
try {
    $gitVersion = (git --version) -replace 'git version ', ''
    Write-Host "  [OK] git v$gitVersion" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: git no esta instalado." -ForegroundColor Red
    Write-Host "  Instala con: winget install Git.Git" -ForegroundColor Yellow
    exit 1
}

# ──────────────────────────────────────────────────────────
# PASO 2: Instalar Qwen Code CLI
# ──────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[2/5] Instalando Qwen Code CLI..." -ForegroundColor Blue

$qwenInstalled = $null
try { $qwenInstalled = Get-Command qwen -ErrorAction SilentlyContinue } catch {}

if ($qwenInstalled) {
    Write-Host "  [OK] Qwen Code ya esta instalado" -ForegroundColor Green
} else {
    Write-Host "  Instalando @qwen-code/qwen-code..."
    npm install -g @qwen-code/qwen-code@latest
    Write-Host "  [OK] Qwen Code instalado" -ForegroundColor Green
}

# ──────────────────────────────────────────────────────────
# PASO 3: Detectar directorio del repo
# ──────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[3/5] Detectando archivos del repo..." -ForegroundColor Blue

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir = Split-Path -Parent $ScriptDir

if (-not (Test-Path "$RepoDir\agents")) {
    Write-Host "  ERROR: No se encontro la carpeta agents\ en $RepoDir" -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] Carpetas agents/ y skills/ encontradas" -ForegroundColor Green

# ──────────────────────────────────────────────────────────
# PASO 4: Instalar Agentes
# ──────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[4/5] Instalando agentes..." -ForegroundColor Blue

$QwenAgentsDir = "$env:USERPROFILE\.qwen\agents"
if (-not (Test-Path $QwenAgentsDir)) {
    New-Item -ItemType Directory -Path $QwenAgentsDir -Force | Out-Null
}

$agentFiles = Get-ChildItem "$RepoDir\agents\*.md"
$agentCount = 0
foreach ($file in $agentFiles) {
    Copy-Item $file.FullName "$QwenAgentsDir\$($file.Name)" -Force
    $agentCount++
}
Write-Host "  [OK] $agentCount agentes instalados en $QwenAgentsDir" -ForegroundColor Green

# ──────────────────────────────────────────────────────────
# PASO 5: Instalar Skills
# ──────────────────────────────────────────────────────────
Write-Host ""
Write-Host "[5/5] Instalando skills..." -ForegroundColor Blue

$QwenSkillsDir = "$env:USERPROFILE\.qwen\skills"
if (-not (Test-Path $QwenSkillsDir)) {
    New-Item -ItemType Directory -Path $QwenSkillsDir -Force | Out-Null
}

$skillDirs = Get-ChildItem "$RepoDir\skills" -Directory
$skillCount = 0
foreach ($dir in $skillDirs) {
    $target = "$QwenSkillsDir\$($dir.Name)"
    Copy-Item $dir.FullName $target -Recurse -Force
    $skillCount++
}
Write-Host "  [OK] $skillCount skills instaladas en $QwenSkillsDir" -ForegroundColor Green

# ──────────────────────────────────────────────────────────
# Copiar QWEN.md
# ──────────────────────────────────────────────────────────
if (Test-Path "$RepoDir\QWEN.md") {
    Copy-Item "$RepoDir\QWEN.md" "$env:USERPROFILE\.qwen\QWEN.md" -Force
    Write-Host "  [OK] QWEN.md copiado" -ForegroundColor Green
}

# ──────────────────────────────────────────────────────────
# Resumen
# ──────────────────────────────────────────────────────────
Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host "            INSTALACION COMPLETADA                       " -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Agentes: $agentCount  |  Skills: $skillCount"
Write-Host ""
Write-Host "  PARA EMPEZAR:" -ForegroundColor Yellow
Write-Host "    1. Abre una nueva terminal"
Write-Host "    2. Escribe: qwen"
Write-Host "    3. Autenticate: /auth"
Write-Host "    4. Ver agentes: /agents manage"
Write-Host "    5. Usar skill: /skills engineering-backend-architect"
Write-Host ""
