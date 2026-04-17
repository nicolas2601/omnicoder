#Requires -Version 5.1
<#
.SYNOPSIS
    OmniCoder v4.3 - Desinstalador COMPLETO para Windows (PowerShell)
.DESCRIPTION
    Elimina TODO: %USERPROFILE%\.omnicoder (agentes, skills, hooks, commands,
    memoria, logs, caches, backups, .env, settings), %USERPROFILE%\.qwen
    (settings + OAuth caches), qwen CLI global, entradas de PATH y variable
    OMNICODER_HOME.
.PARAMETER KeepMemory
    Conserva %USERPROFILE%\.omnicoder\memory (aprendizajes)
.PARAMETER KeepQwen
    No desinstala qwen CLI (solo OmniCoder)
.PARAMETER Force
    No pide confirmacion
.PARAMETER DryRun
    Solo muestra que eliminaria, no toca nada
.EXAMPLE
    .\uninstall-windows.ps1
    .\uninstall-windows.ps1 -Force -KeepMemory
    .\uninstall-windows.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [switch]$KeepMemory,
    [switch]$KeepQwen,
    [switch]$Force,
    [switch]$DryRun
)

$ErrorActionPreference = 'Continue'  # No abortar si un Remove-Item falla

$OmniHome = Join-Path $env:USERPROFILE '.omnicoder'
$QwenHome = Join-Path $env:USERPROFILE '.qwen'
$MemoryBackup = $null

Write-Host ''
Write-Host '=== OmniCoder - Desinstalador Completo (Windows) ===' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Esto eliminara:' -ForegroundColor Yellow
Write-Host "  - $OmniHome (TODO: agents, skills, hooks, commands,"
Write-Host '    config, logs, .cache, .backups, bin)'
if (-not $KeepMemory) {
    Write-Host '    + memory/ (aprendizajes, patterns, trajectories)'
} else {
    Write-Host '    (memory/ se conserva: -KeepMemory)' -ForegroundColor DarkGray
}
Write-Host "  - $QwenHome\settings.json, QWEN.md, commands\ y caches OAuth residuales"
if (-not $KeepQwen) {
    Write-Host '  - Paquete global: @qwen-code/qwen-code (npm uninstall -g)'
} else {
    Write-Host '  (qwen CLI se conserva: -KeepQwen)' -ForegroundColor DarkGray
}
Write-Host "  - PATH de usuario: remover $OmniHome"
Write-Host '  - Variable OMNICODER_HOME (scope User)'
Write-Host ''

if ($DryRun) {
    Write-Host '-DryRun: no se tocara nada.' -ForegroundColor DarkGray
    exit 0
}

if (-not $Force) {
    $confirm = Read-Host 'Continuar? [y/N]'
    if ($confirm -notmatch '^[yYsS]$') {
        Write-Host 'Cancelado.' -ForegroundColor Red
        exit 0
    }
}

function Remove-Safe {
    param([string]$Path, [string]$Label)
    if (Test-Path $Path) {
        try {
            Remove-Item -Recurse -Force $Path -ErrorAction Stop
            Write-Host "  [OK] $Label eliminado" -ForegroundColor Green
        } catch {
            Write-Host "  [!!] Error eliminando $Label : $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# 1. Backup de memoria si -KeepMemory
if ($KeepMemory -and (Test-Path "$OmniHome\memory")) {
    $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
    $MemoryBackup = Join-Path $env:USERPROFILE ".omnicoder-memory-backup-$ts.zip"
    try {
        Compress-Archive -Path "$OmniHome\memory" -DestinationPath $MemoryBackup -Force
        Write-Host "  [OK] memory/ respaldada en: $MemoryBackup" -ForegroundColor Green
    } catch {
        Write-Host "  [!!] No se pudo respaldar memory/: $($_.Exception.Message)" -ForegroundColor Yellow
        $MemoryBackup = $null
    }
}

# 2. Eliminar OmniCoder home
if (Test-Path $OmniHome) {
    if ($KeepMemory -and (Test-Path "$OmniHome\memory")) {
        # Eliminar todo excepto memory/
        Get-ChildItem -Path $OmniHome -Force | Where-Object { $_.Name -ne 'memory' } | ForEach-Object {
            try { Remove-Item -Recurse -Force $_.FullName -ErrorAction Stop } catch {}
        }
        Write-Host "  [OK] $OmniHome limpiado (memory/ conservada)" -ForegroundColor Green
    } else {
        Remove-Safe $OmniHome 'OmniCoder home completo'
    }
}

# 3. Limpiar ~/.qwen/ (settings + OAuth caches + QWEN.md + commands/)
# v4.3.2: QWEN.md y commands/ los creamos con install copiando de OmniCoder.
if (Test-Path $QwenHome) {
    $qwenFiles = @('settings.json','QWEN.md','oauth_creds.json','access_token','refresh_token','.qwen_session','auth.json')
    foreach ($f in $qwenFiles) {
        $p = Join-Path $QwenHome $f
        if (Test-Path $p) { Remove-Item $p -Force -ErrorAction SilentlyContinue }
    }
    $qwenCmds = Join-Path $QwenHome 'commands'
    if (Test-Path $qwenCmds) { Remove-Item $qwenCmds -Recurse -Force -ErrorAction SilentlyContinue }
    $remaining = Get-ChildItem -Path $QwenHome -Force -ErrorAction SilentlyContinue
    if (-not $remaining) {
        Remove-Item $QwenHome -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] $QwenHome eliminado (estaba vacio tras limpieza)" -ForegroundColor Green
    } else {
        Write-Host "  [OK] $QwenHome caches OAuth limpiados" -ForegroundColor Green
    }
}

# 4. Desinstalar qwen CLI global
if (-not $KeepQwen) {
    $npm = Get-Command npm -ErrorAction SilentlyContinue
    if ($npm) {
        $listed = & npm list -g --depth=0 2>$null | Select-String '@qwen-code/qwen-code'
        if ($listed) {
            & npm uninstall -g '@qwen-code/qwen-code' 2>$null | Out-Null
            Write-Host '  [OK] @qwen-code/qwen-code desinstalado' -ForegroundColor Green
        } else {
            Write-Host '  [--] qwen CLI no estaba instalado globalmente' -ForegroundColor DarkGray
        }
    } else {
        Write-Host '  [!!] npm no disponible, no se pudo desinstalar qwen CLI' -ForegroundColor Yellow
    }
}

# 5. Limpiar PATH de usuario + variable OMNICODER_HOME
try {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($userPath) {
        $entries = $userPath -split ';' | Where-Object { $_ -and $_ -notlike '*\.omnicoder*' }
        $cleaned = ($entries -join ';').Trim(';')
        if ($cleaned -ne $userPath) {
            [Environment]::SetEnvironmentVariable('Path', $cleaned, 'User')
            Write-Host '  [OK] Entrada .omnicoder removida del PATH de usuario' -ForegroundColor Green
        }
    }
    if ([Environment]::GetEnvironmentVariable('OMNICODER_HOME', 'User')) {
        [Environment]::SetEnvironmentVariable('OMNICODER_HOME', $null, 'User')
        Write-Host '  [OK] Variable OMNICODER_HOME (User) eliminada' -ForegroundColor Green
    }
} catch {
    Write-Host "  [!!] No se pudo limpiar PATH/env vars: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'Desinstalacion completa.' -ForegroundColor Cyan
if ($MemoryBackup) {
    Write-Host "Tu memoria esta respaldada en: $MemoryBackup" -ForegroundColor DarkGray
}
Write-Host ''
Write-Host 'Para reinstalar limpio:' -ForegroundColor Yellow
Write-Host '  git clone https://github.com/nicolas2601/omnicoder.git'
Write-Host '  cd omnicoder'
Write-Host '  .\scripts\install-windows.ps1          # PowerShell'
Write-Host '  .\scripts\install-windows.bat          # CMD'
Write-Host ''
Write-Host 'Reinicia tu terminal' -ForegroundColor Yellow -NoNewline
Write-Host ' para que los cambios en PATH surtan efecto.'
