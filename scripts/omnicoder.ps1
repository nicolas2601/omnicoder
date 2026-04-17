# ============================================================
# OmniCoder v4.3 - CLI Wrapper for Windows PowerShell
# Lanza qwen CLI con branding OmniCoder y carga .env auto
# ============================================================

$OmniVersion = "4.3.0"
$OmniDir = if ($env:OMNICODER_HOME) { $env:OMNICODER_HOME } else { "$env:USERPROFILE\.omnicoder" }

# --- Verificar bash en PATH (hooks lo requieren) ---
if (-not (Get-Command bash -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "[OmniCoder] AVISO: bash no encontrado en PATH." -ForegroundColor Yellow
    Write-Host "            Los hooks no funcionaran sin Git Bash o WSL." -ForegroundColor DarkGray
    Write-Host "            Instala: https://git-scm.com/download/win" -ForegroundColor DarkGray
    Write-Host ""
}

# --- Garantizar ~/.qwen/settings.json apunta a los hooks de OmniCoder ---
$qwenSettings = Join-Path $env:USERPROFILE '.qwen\settings.json'
$omniSettings = Join-Path $OmniDir 'settings.json'
if ((-not (Test-Path $qwenSettings)) -and (Test-Path $omniSettings)) {
    $qwenDir = Join-Path $env:USERPROFILE '.qwen'
    if (-not (Test-Path $qwenDir)) { New-Item -ItemType Directory -Path $qwenDir -Force | Out-Null }
    try { Copy-Item $omniSettings $qwenSettings -Force } catch {}
}

# Cargar .env si existe (provider activo, ignora comentarios y lineas vacias)
if (Test-Path "$OmniDir\.env") {
    Get-Content "$OmniDir\.env" | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith('#')) {
            if ($line -match '^([^=]+)=(.*)$') {
                $k = $Matches[1].Trim()
                $v = $Matches[2].Trim().Trim('"').Trim("'")
                [Environment]::SetEnvironmentVariable($k, $v, 'Process')
            }
        }
    }
}

# v4.3.1 FIX: forzar auth por API key y limpiar caches OAuth residuales.
# Sin esto qwen seguia pidiendo auth interactivo aunque OPENAI_API_KEY estuviera
# en .env, porque detectaba oauth_creds.json o tokens cacheados previos.
if ($env:OPENAI_API_KEY) {
    $env:QWEN_AUTH_TYPE = 'openai'
    $env:QWEN_NO_TELEMETRY = '1'
    $QwenDir = Join-Path $env:USERPROFILE '.qwen'
    foreach ($f in @('oauth_creds.json','access_token','refresh_token','.qwen_session','auth.json')) {
        $path = Join-Path $QwenDir $f
        if (Test-Path $path) { Remove-Item $path -Force -ErrorAction SilentlyContinue }
    }
}

# Detector de provider friendly name
function Get-ProviderName {
    param([string]$Url)
    if (-not $Url) { return '(no configurado)' }
    switch -Regex ($Url) {
        'nvidia'                 { return 'NVIDIA NIM (MiniMax M2.7)' }
        'generativelanguage'     { return 'Google Gemini' }
        'api\.minimax'           { return 'MiniMax (direct)' }
        'deepseek'               { return 'DeepSeek' }
        'openrouter'             { return 'OpenRouter' }
        'localhost|127\.0\.0\.1' { return 'Ollama (local)' }
        default                  { return "custom ($Url)" }
    }
}

# --version / -v
if ($args.Count -gt 0 -and ($args[0] -eq '--version' -or $args[0] -eq '-v')) {
    $agents = 0; $skills = 0; $hooks = 0; $cmds = 0
    if (Test-Path "$OmniDir\agents")   { $agents = (Get-ChildItem "$OmniDir\agents\*.md" -ErrorAction SilentlyContinue).Count }
    if (Test-Path "$OmniDir\skills")   { $skills = (Get-ChildItem "$OmniDir\skills" -Directory -ErrorAction SilentlyContinue).Count }
    if (Test-Path "$OmniDir\hooks")    { $hooks  = (Get-ChildItem "$OmniDir\hooks\*.sh" -ErrorAction SilentlyContinue).Count }
    if (Test-Path "$OmniDir\commands") { $cmds   = (Get-ChildItem "$OmniDir\commands\*.md" -ErrorAction SilentlyContinue).Count }

    if ($agents -eq 0) { $agents = 168 }
    if ($skills -eq 0) { $skills = 193 }
    if ($hooks  -eq 0) { $hooks  = 18 }
    if ($cmds   -eq 0) { $cmds   = 21 }

    $qwenVer = '(no instalado)'
    try {
        $null = Get-Command qwen -ErrorAction Stop
        $qwenVer = (& qwen --version 2>$null | Select-Object -First 1).Trim()
        if (-not $qwenVer) { $qwenVer = 'unknown' }
    } catch {}

    $provider = Get-ProviderName $env:OPENAI_BASE_URL

    Write-Host ""
    Write-Host "OmniCoder v$OmniVersion" -ForegroundColor Cyan
    Write-Host "  Qwen Code CLI:    $qwenVer" -ForegroundColor DarkGray
    Write-Host "  Provider:         $provider" -ForegroundColor DarkGray
    Write-Host "  Agents:           $agents" -ForegroundColor DarkGray
    Write-Host "  Skills:           $skills" -ForegroundColor DarkGray
    Write-Host "  Hooks:            $hooks" -ForegroundColor DarkGray
    Write-Host "  Commands:         $cmds" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Installation: $OmniDir" -ForegroundColor DarkGray
    Write-Host "Repo:         https://github.com/nicolas2601/omnicoder" -ForegroundColor DarkGray
    Write-Host "License:      MIT" -ForegroundColor DarkGray
    Write-Host ""
    exit 0
}

# Headless mode: si el primer arg es -p / --prompt, saltar banner
$skipBanner = ($args.Count -gt 0) -and ($args[0] -eq '-p' -or $args[0] -eq '--prompt')

if (-not $skipBanner) {
    Write-Host ""
    Write-Host "    ___                  _  ___          _              " -ForegroundColor Cyan
    Write-Host "   / _ \ _ __ ___  _ __ (_)/ __\___   __| | ___ _ __     " -ForegroundColor Cyan
    Write-Host "  | | | | '_ `` _ \| '_ \| / /  / _ \ / _`` |/ _ \ '__|   " -ForegroundColor Cyan
    Write-Host "  | |_| | | | | | | | | | / /__| (_) | (_| |  __/ |      " -ForegroundColor Cyan
    Write-Host "   \___/|_| |_| |_|_| |_|_\____/\___/ \__,_|\___|_|      " -ForegroundColor Cyan
    Write-Host ""

    $provider = Get-ProviderName $env:OPENAI_BASE_URL
    Write-Host "  OmniCoder v$OmniVersion " -ForegroundColor White -NoNewline
    Write-Host "- $provider" -ForegroundColor DarkGray
    if ($env:OPENAI_MODEL) {
        Write-Host "  Model: $env:OPENAI_MODEL" -ForegroundColor Green
    }
    Write-Host "  168 agents . 193 skills . 18 hooks . 21 commands" -ForegroundColor DarkGray
    Write-Host ""
}

# Verificar que qwen exista antes de lanzar
if (-not (Get-Command qwen -ErrorAction SilentlyContinue)) {
    Write-Host "[OmniCoder] ERROR: qwen no encontrado. Reinstala con:" -ForegroundColor Red
    Write-Host "            npm install -g @qwen-code/qwen-code@latest" -ForegroundColor DarkGray
    exit 1
}

try {
    & qwen @args
    exit $LASTEXITCODE
} catch {
    Write-Host "[OmniCoder] qwen fallo: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
