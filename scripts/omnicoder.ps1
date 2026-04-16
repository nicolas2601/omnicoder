# ============================================================
# OmniCoder - CLI Wrapper for Windows PowerShell
# Lanza qwen CLI con branding OmniCoder y carga .env auto
# ============================================================

$OmniDir = "$env:USERPROFILE\.omnicoder"

# Cargar .env si existe (provider activo)
if (Test-Path "$OmniDir\.env") {
    Get-Content "$OmniDir\.env" | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            [Environment]::SetEnvironmentVariable($Matches[1].Trim(), $Matches[2].Trim(), 'Process')
        }
    }
}

# Headless mode: si el primer arg es -p, saltar banner
$skipBanner = ($args.Count -gt 0) -and ($args[0] -eq '-p')

if (-not $skipBanner) {
    Write-Host ""
    Write-Host "   ____                  _ ______          __" -ForegroundColor Cyan
    Write-Host "  / __ \____ ___  ____  (_) ____/___  ____/ /__  _____" -ForegroundColor Cyan
    Write-Host " / / / / __ ``__ \/ __ \/ / /   / __ \/ __  / _ \/ ___/" -ForegroundColor Cyan
    Write-Host "/ /_/ / / / / / / / / / / /___/ /_/ / /_/ /  __/ /" -ForegroundColor Cyan
    Write-Host "\____/_/ /_/ /_/_/ /_/_/\____/\____/\__,_/\___/_/" -ForegroundColor Cyan
    Write-Host ""

    # Mostrar info del provider activo
    if ($env:OPENAI_MODEL) {
        Write-Host "  Model: " -ForegroundColor DarkGray -NoNewline
        Write-Host "$env:OPENAI_MODEL" -ForegroundColor Green
    }
    if ($env:OPENAI_BASE_URL) {
        $providerName = "custom"
        switch -Regex ($env:OPENAI_BASE_URL) {
            'nvidia'              { $providerName = "NVIDIA NIM" }
            'generativelanguage'  { $providerName = "Google Gemini" }
            'minimax'             { $providerName = "MiniMax" }
            'deepseek'            { $providerName = "DeepSeek" }
            'openrouter'          { $providerName = "OpenRouter" }
            'localhost|127\.0\.0\.1' { $providerName = "Ollama (local)" }
        }
        Write-Host "  Provider: " -ForegroundColor DarkGray -NoNewline
        Write-Host "$providerName" -ForegroundColor Green
    }
    Write-Host "  168 agentes | 193 skills | 16 hooks | 20 commands" -ForegroundColor DarkGray
    Write-Host ""
}

# Pasar todo a qwen
& qwen @args
