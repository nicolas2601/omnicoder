# ============================================================
# Qwen Con Poderes - Setup Provider Interactivo (v1.0) - Windows
#
# Pide la API key, genera %USERPROFILE%\.qwen\.env.<provider>
# y activa el provider.
#
# Uso (PowerShell):
#   .\setup-provider.ps1
#   .\setup-provider.ps1 -Provider nvidia
#
# Si execution policy bloquea:
#   powershell -ExecutionPolicy Bypass -File .\setup-provider.ps1
# ============================================================
[CmdletBinding()]
param(
    [ValidateSet('nvidia','gemini','minimax','deepseek','openrouter','')]
    [string]$Provider = ''
)

$ErrorActionPreference = 'Stop'
$QwenDir = Join-Path $env:USERPROFILE '.qwen'
$SettingsFile = Join-Path $QwenDir 'settings.json'

if (-not (Test-Path $QwenDir)) { New-Item -ItemType Directory -Path $QwenDir | Out-Null }

$Providers = @{
    nvidia     = @{ Url='https://integrate.api.nvidia.com/v1';                          Model='minimaxai/minimax-m2.7';            Signup='https://build.nvidia.com/  (gratis 40 RPM)' }
    gemini     = @{ Url='https://generativelanguage.googleapis.com/v1beta/openai/';     Model='gemini-2.5-flash';                  Signup='https://aistudio.google.com/apikey  (gratis 1500/dia)' }
    minimax    = @{ Url='https://api.minimax.io/v1';                                    Model='MiniMax-M2';                        Signup='https://www.minimax.io/platform  (paid)' }
    deepseek   = @{ Url='https://api.deepseek.com/v1';                                  Model='deepseek-chat';                     Signup='https://platform.deepseek.com/  (paid)' }
    openrouter = @{ Url='https://openrouter.ai/api/v1';                                 Model='deepseek/deepseek-chat-v3-0324:free'; Signup='https://openrouter.ai/keys  (free tier)' }
}

function Show-Menu {
    Write-Host ""
    Write-Host "=== Qwen Con Poderes - Setup Provider ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Providers disponibles:"
    Write-Host "  1) nvidia      MiniMax M2.7 via NVIDIA NIM   [FREE 40 RPM] " -NoNewline
    Write-Host "(recomendado)" -ForegroundColor Green
    Write-Host "  2) gemini      Gemini 2.5 Flash              [FREE 1500/dia]"
    Write-Host "  3) minimax     MiniMax API directo           [paid Starter `$10]"
    Write-Host "  4) deepseek    DeepSeek V3.2                 [paid, cache 90% off]"
    Write-Host "  5) openrouter  OpenRouter + DeepSeek         [free tier]"
    Write-Host ""
    $opt = Read-Host "Eleccion [1-5, default=1]"
    if ([string]::IsNullOrWhiteSpace($opt)) { $opt = '1' }
    switch ($opt) {
        '1' { return 'nvidia' }
        '2' { return 'gemini' }
        '3' { return 'minimax' }
        '4' { return 'deepseek' }
        '5' { return 'openrouter' }
        default { Write-Host "Opcion invalida" -ForegroundColor Red; exit 1 }
    }
}

if ([string]::IsNullOrWhiteSpace($Provider)) { $Provider = Show-Menu }

$cfg = $Providers[$Provider]
$envFile = Join-Path $QwenDir ".env.$Provider"
$activeEnv = Join-Path $QwenDir '.env'
$backupEnv = Join-Path $QwenDir '.env.backup'

Write-Host ""
Write-Host "Provider: $Provider" -ForegroundColor Cyan
Write-Host "Base URL: $($cfg.Url)"
Write-Host "Modelo:   $($cfg.Model)"
Write-Host "Registro: $($cfg.Signup)"
Write-Host ""

if (Test-Path $envFile) {
    $ow = Read-Host "Ya existe $envFile. Sobrescribir? [y/N]"
    if ($ow.ToLower() -ne 'y') { Write-Host "Cancelado."; exit 0 }
}

# Pedir API key oculta
Write-Host ""
$secure = Read-Host "Pega tu API key de $Provider (no se mostrara)" -AsSecureString
$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
$apiKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) | Out-Null

if ([string]::IsNullOrWhiteSpace($apiKey)) {
    Write-Host "API key vacia. Abortando." -ForegroundColor Red
    exit 1
}
if ($apiKey.Length -lt 20) {
    Write-Host "Aviso: la key parece corta ($($apiKey.Length) chars). Continuando..." -ForegroundColor Yellow
}

# Escribir .env.<provider>
$ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$content = @"
# Generado por setup-provider.ps1 el $ts
OPENAI_API_KEY=$apiKey
OPENAI_BASE_URL=$($cfg.Url)
OPENAI_MODEL=$($cfg.Model)
"@
[System.IO.File]::WriteAllText($envFile, $content, [System.Text.UTF8Encoding]::new($false))

# Restringir permisos (solo usuario actual)
try {
    $acl = Get-Acl $envFile
    $acl.SetAccessRuleProtection($true, $false)
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $env:USERNAME, 'FullControl', 'Allow')
    $acl.SetAccessRule($rule)
    Set-Acl $envFile $acl
} catch {
    Write-Host "Aviso: no se pudieron restringir permisos NTFS ($_)" -ForegroundColor Yellow
}
Write-Host "OK escrito $envFile" -ForegroundColor Green

# Activar: backup .env actual y copiar el nuevo
if (Test-Path $activeEnv) { Copy-Item $activeEnv $backupEnv -Force }
Copy-Item $envFile $activeEnv -Force
Write-Host "OK provider activo (backup en $backupEnv)" -ForegroundColor Green

# Actualizar settings.json (model.name + security.auth.selectedType=openai)
if (Test-Path $SettingsFile) {
    try {
        $json = Get-Content $SettingsFile -Raw | ConvertFrom-Json
        if (-not $json.model) { $json | Add-Member -NotePropertyName model -NotePropertyValue ([PSCustomObject]@{}) -Force }
        $json.model | Add-Member -NotePropertyName name -NotePropertyValue $cfg.Model -Force
        # CRITICO: forzar selectedType=openai (sino Qwen pide OAuth al arrancar)
        if (-not $json.security) { $json | Add-Member -NotePropertyName security -NotePropertyValue ([PSCustomObject]@{}) -Force }
        if (-not $json.security.auth) { $json.security | Add-Member -NotePropertyName auth -NotePropertyValue ([PSCustomObject]@{}) -Force }
        $json.security.auth | Add-Member -NotePropertyName selectedType -NotePropertyValue 'openai' -Force
        $json | ConvertTo-Json -Depth 20 | Set-Content $SettingsFile -Encoding UTF8
        Write-Host "OK settings.json: model.name=$($cfg.Model), auth.selectedType=openai" -ForegroundColor Green
    } catch {
        Write-Host "Aviso: no se pudo actualizar settings.json ($_)" -ForegroundColor Yellow
    }
}

# Eliminar OAuth cacheado (sino prioriza sobre la API key)
$oauthCreds = Join-Path $QwenDir 'oauth_creds.json'
if (Test-Path $oauthCreds) {
    Write-Host ""
    $rm = Read-Host "Encontre OAuth cacheado de Qwen. Eliminar para usar tu API key? [Y/n]"
    if ($rm.ToLower() -ne 'n') {
        Remove-Item $oauthCreds -Force
        Write-Host "OK OAuth eliminado" -ForegroundColor Green
    }
}

# Test opcional
Write-Host ""
$test = Read-Host "Probar conexion con la API ahora? [Y/n]"
if ($test.ToLower() -ne 'n') {
    try {
        $body = @{
            model    = $cfg.Model
            messages = @(@{ role='user'; content='ping' })
            max_tokens = 5
        } | ConvertTo-Json -Depth 5
        $headers = @{ 'Authorization' = "Bearer $apiKey"; 'Content-Type' = 'application/json' }
        $url = ($cfg.Url.TrimEnd('/')) + '/chat/completions'
        $r = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -TimeoutSec 20
        Write-Host "OK conexion exitosa" -ForegroundColor Green
    } catch {
        Write-Host "Error en test: $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Listo! Arranca Qwen con:" -ForegroundColor Green
Write-Host "  qwen" -ForegroundColor Cyan
Write-Host "(Qwen Code lee automaticamente $activeEnv)"
