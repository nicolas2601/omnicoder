# ============================================================
# OmniCoder v4.2 - Desinstalador para Windows (PowerShell)
# ============================================================
# Uso: .\scripts\uninstall-windows.ps1 [-Force]
#   -Force : No pide confirmacion
# ============================================================

param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=== OmniCoder v4.2 - Desinstalador (Windows) ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Esto eliminara:" -ForegroundColor Yellow
Write-Host "  - Todos los agentes de %USERPROFILE%\.omnicoder\agents\"
Write-Host "  - Todas las skills de %USERPROFILE%\.omnicoder\skills\"
Write-Host "  - Todos los hooks de %USERPROFILE%\.omnicoder\hooks\"
Write-Host "  - Todos los commands de %USERPROFILE%\.omnicoder\commands\"
Write-Host "  - El archivo OMNICODER.md de %USERPROFILE%\.omnicoder\"
Write-Host "  - Los logs de %USERPROFILE%\.omnicoder\logs\"
Write-Host "  - La seccion 'hooks' de settings.json (si existe)"
Write-Host ""
Write-Host "NO eliminara:" -ForegroundColor Green
Write-Host "  - OmniCoder CLI"
Write-Host "  - settings.json (solo limpia la seccion hooks)"
Write-Host "  - Tus handoff documents"
Write-Host ""

if (-not $Force) {
    $confirm = Read-Host "Continuar? (s/n)"
    if ($confirm -ne "s" -and $confirm -ne "S") {
        Write-Host "Cancelado." -ForegroundColor Red
        exit 0
    }
}

$OmniDir = "$env:USERPROFILE\.omnicoder"

function Remove-IfExists {
    param([string]$Path, [string]$Label)
    if (Test-Path $Path) {
        Remove-Item -Recurse -Force $Path
        Write-Host "  [OK] $Label eliminado" -ForegroundColor Green
    }
}

Remove-IfExists "$OmniDir\agents"   "Agentes"
Remove-IfExists "$OmniDir\skills"   "Skills"
Remove-IfExists "$OmniDir\hooks"    "Hooks"
Remove-IfExists "$OmniDir\commands" "Commands"
Remove-IfExists "$OmniDir\logs"     "Logs"
Remove-IfExists "$OmniDir\OMNICODER.md"  "OMNICODER.md"

# Limpiar hooks del settings.json (causa del timeout en Windows sin bash)
$SettingsPath = "$OmniDir\settings.json"
if (Test-Path $SettingsPath) {
    try {
        $json = Get-Content $SettingsPath -Raw | ConvertFrom-Json
        if ($json.PSObject.Properties.Name -contains "hooks") {
            $json.PSObject.Properties.Remove("hooks")
            $json | ConvertTo-Json -Depth 20 | Set-Content $SettingsPath -Encoding UTF8
            Write-Host "  [OK] Seccion 'hooks' removida de settings.json" -ForegroundColor Green
        }
    } catch {
        Write-Host "  [WARN] No se pudo parsear settings.json. Revisa manualmente: $SettingsPath" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Desinstalacion completada." -ForegroundColor Cyan
Write-Host ""
Write-Host "Para desinstalar OmniCoder CLI:" -ForegroundColor Yellow
Write-Host "  npm uninstall -g @qwen-code/qwen-code"
Write-Host ""
Write-Host "Para reinstalar desde Git Bash (RECOMENDADO en Windows):" -ForegroundColor Yellow
Write-Host "  1. Instala Git for Windows: https://git-scm.com/download/win"
Write-Host "  2. Abre 'Git Bash' (no PowerShell ni CMD)"
Write-Host "  3. Ejecuta:"
Write-Host "     git clone https://github.com/nicolas2601/omnicoder.git"
Write-Host "     cd omnicoder"
Write-Host "     chmod +x scripts/install-linux.sh"
Write-Host "     ./scripts/install-linux.sh"
Write-Host ""
