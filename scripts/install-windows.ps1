# ============================================================
# Qwen Con Poderes v3.4 - Instalador para Windows (PowerShell)
# 168 agentes + 193 skills + 15 hooks + 20 commands + settings
# ============================================================
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "    QWEN CON PODERES v2.0 - INSTALADOR WINDOWS          " -ForegroundColor Cyan
Write-Host "    168 Agentes + 193 Skills + 7 Hooks + 11 Commands     " -ForegroundColor Cyan
Write-Host "    Token optimization | Security hooks | Auto-routing    " -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir = Split-Path -Parent $ScriptDir

# ── PASO 1: Requisitos ──
Write-Host "[1/8] Verificando requisitos..." -ForegroundColor Blue
try {
    $nv = (node -v) -replace 'v', ''
    if ([int]($nv.Split('.')[0]) -lt 20) { Write-Host "  ERROR: Node.js v20+ requerido" -ForegroundColor Red; exit 1 }
    Write-Host "  [OK] Node.js v$nv" -ForegroundColor Green
} catch { Write-Host "  ERROR: Node.js no instalado. winget install OpenJS.NodeJS.LTS" -ForegroundColor Red; exit 1 }

try { $null = npm -v; Write-Host "  [OK] npm" -ForegroundColor Green } catch { Write-Host "  ERROR: npm no instalado" -ForegroundColor Red; exit 1 }
try { $null = git --version; Write-Host "  [OK] git" -ForegroundColor Green } catch { Write-Host "  ERROR: git no instalado" -ForegroundColor Red; exit 1 }

# ── PASO 2: Qwen CLI ──
Write-Host "`n[2/8] Qwen Code CLI..." -ForegroundColor Blue
try { $null = Get-Command qwen -ErrorAction Stop; Write-Host "  [OK] Ya instalado" -ForegroundColor Green }
catch { npm install -g @qwen-code/qwen-code@latest; Write-Host "  [OK] Instalado" -ForegroundColor Green }

# ── PASO 3: Verificar repo ──
Write-Host "`n[3/8] Verificando repo..." -ForegroundColor Blue
if (-not (Test-Path "$RepoDir\agents")) { Write-Host "  ERROR: agents\ no encontrado" -ForegroundColor Red; exit 1 }
Write-Host "  [OK] Repo detectado" -ForegroundColor Green

# ── PASO 4: Agentes ──
Write-Host "`n[4/8] Instalando agentes..." -ForegroundColor Blue
$AgentsDir = "$env:USERPROFILE\.qwen\agents"
New-Item -ItemType Directory -Path $AgentsDir -Force | Out-Null
$ac = 0; Get-ChildItem "$RepoDir\agents\*.md" | ForEach-Object { Copy-Item $_.FullName "$AgentsDir\$($_.Name)" -Force; $ac++ }
Write-Host "  [OK] $ac agentes" -ForegroundColor Green

# ── PASO 5: Skills ──
Write-Host "`n[5/8] Instalando skills..." -ForegroundColor Blue
$SkillsDir = "$env:USERPROFILE\.qwen\skills"
New-Item -ItemType Directory -Path $SkillsDir -Force | Out-Null
$sc = 0; Get-ChildItem "$RepoDir\skills" -Directory | ForEach-Object { Copy-Item $_.FullName "$SkillsDir\$($_.Name)" -Recurse -Force; $sc++ }
Write-Host "  [OK] $sc skills" -ForegroundColor Green

# ── PASO 6: Hooks ──
Write-Host "`n[6/8] Instalando hooks..." -ForegroundColor Blue
$HooksDir = "$env:USERPROFILE\.qwen\hooks"
New-Item -ItemType Directory -Path $HooksDir -Force | Out-Null
$hc = 0; Get-ChildItem "$RepoDir\hooks\*.sh" | ForEach-Object { Copy-Item $_.FullName "$HooksDir\$($_.Name)" -Force; $hc++ }
Write-Host "  [OK] $hc hooks" -ForegroundColor Green

# ── PASO 7: Commands ──
Write-Host "`n[7/8] Instalando commands..." -ForegroundColor Blue
$CmdsDir = "$env:USERPROFILE\.qwen\commands"
New-Item -ItemType Directory -Path $CmdsDir -Force | Out-Null
$cc = 0; Get-ChildItem "$RepoDir\commands\*.md" | ForEach-Object { Copy-Item $_.FullName "$CmdsDir\$($_.Name)" -Force; $cc++ }
Write-Host "  [OK] $cc commands" -ForegroundColor Green

# ── PASO 8: Config ──
Write-Host "`n[8/8] Configurando..." -ForegroundColor Blue
if (Test-Path "$RepoDir\QWEN.md") { Copy-Item "$RepoDir\QWEN.md" "$env:USERPROFILE\.qwen\QWEN.md" -Force; Write-Host "  [OK] QWEN.md" -ForegroundColor Green }
if (Test-Path "$RepoDir\config\settings.json") { Copy-Item "$RepoDir\config\settings.json" "$env:USERPROFILE\.qwen\settings.json" -Force; Write-Host "  [OK] settings.json" -ForegroundColor Green }
New-Item -ItemType Directory -Path "$env:USERPROFILE\.qwen\logs" -Force | Out-Null

# ── Resumen ──
Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "           INSTALACION COMPLETADA v2.0                    " -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host "`n  Agentes: $ac | Skills: $sc | Hooks: $hc | Commands: $cc"
Write-Host "`n  PARA EMPEZAR:" -ForegroundColor Yellow
Write-Host "    qwen                   Iniciar Qwen Code"
Write-Host "    /agents manage         Ver agentes"
Write-Host "    /skills                Ver skills"
Write-Host "    /review                Code review"
Write-Host "    /ship                  Test+lint+commit+push"
Write-Host "    /audit                 Auditoria completa"
Write-Host "    /handoff               Guardar progreso"
Write-Host ""
