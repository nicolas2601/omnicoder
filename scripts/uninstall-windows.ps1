# ============================================================
# Qwen Con Poderes v2 - Desinstalador para Windows (PowerShell)
# ============================================================
# Uso: .\scripts\uninstall-windows.ps1 [-Force]
#   -Force : No pide confirmacion
# ============================================================

param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=== Qwen Con Poderes v2 - Desinstalador (Windows) ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Esto eliminara:" -ForegroundColor Yellow
Write-Host "  - Todos los agentes de %USERPROFILE%\.qwen\agents\"
Write-Host "  - Todas las skills de %USERPROFILE%\.qwen\skills\"
Write-Host "  - Todos los hooks de %USERPROFILE%\.qwen\hooks\"
Write-Host "  - Todos los commands de %USERPROFILE%\.qwen\commands\"
Write-Host "  - El archivo QWEN.md de %USERPROFILE%\.qwen\"
Write-Host "  - Los logs de %USERPROFILE%\.qwen\logs\"
Write-Host "  - La seccion 'hooks' de settings.json (si existe)"
Write-Host ""
Write-Host "NO eliminara:" -ForegroundColor Green
Write-Host "  - Qwen Code CLI"
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

$QwenDir = "$env:USERPROFILE\.qwen"

function Remove-IfExists {
    param([string]$Path, [string]$Label)
    if (Test-Path $Path) {
        Remove-Item -Recurse -Force $Path
        Write-Host "  [OK] $Label eliminado" -ForegroundColor Green
    }
}

Remove-IfExists "$QwenDir\agents"   "Agentes"
Remove-IfExists "$QwenDir\skills"   "Skills"
Remove-IfExists "$QwenDir\hooks"    "Hooks"
Remove-IfExists "$QwenDir\commands" "Commands"
Remove-IfExists "$QwenDir\logs"     "Logs"
Remove-IfExists "$QwenDir\QWEN.md"  "QWEN.md"

# Limpiar hooks del settings.json (causa del timeout en Windows sin bash)
$SettingsPath = "$QwenDir\settings.json"
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
Write-Host "Para desinstalar Qwen Code CLI:" -ForegroundColor Yellow
Write-Host "  npm uninstall -g @qwen-code/qwen-code"
Write-Host ""
Write-Host "Para reinstalar desde Git Bash (RECOMENDADO en Windows):" -ForegroundColor Yellow
Write-Host "  1. Instala Git for Windows: https://git-scm.com/download/win"
Write-Host "  2. Abre 'Git Bash' (no PowerShell ni CMD)"
Write-Host "  3. Ejecuta:"
Write-Host "     git clone https://github.com/nicolas2601/qwen-con-poderes-.git"
Write-Host "     cd qwen-con-poderes-"
Write-Host "     chmod +x scripts/install-linux.sh"
Write-Host "     ./scripts/install-linux.sh"
Write-Host ""
