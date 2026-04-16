# ============================================================
# OmniCoder - Setup Provider Interactivo (v1.0) - Windows
#
# Pide la API key, genera %USERPROFILE%\.omnicoder\.env.<provider>
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
$OmniDir = Join-Path $env:USERPROFILE '.omnicoder'
$QwenDir = Join-Path $env:USERPROFILE '.qwen'   # CRITICO: qwen CLI lee hardcoded de aqui
$SettingsFile = Join-Path $OmniDir 'settings.json'
$QwenSettingsFile = Join-Path $QwenDir 'settings.json'

if (-not (Test-Path $OmniDir)) { New-Item -ItemType Directory -Path $OmniDir | Out-Null }
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
    Write-Host "=== OmniCoder - Setup Provider ===" -ForegroundColor Cyan
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
$envFile = Join-Path $OmniDir ".env.$Provider"
$activeEnv = Join-Path $OmniDir '.env'
$backupEnv = Join-Path $OmniDir '.env.backup'

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

# Activar: backup .env actual y copiar el nuevo a ambos sitios
if (Test-Path $activeEnv) { Copy-Item $activeEnv $backupEnv -Force }
Copy-Item $envFile $activeEnv -Force
# CRITICO: replicar .env a ~/.qwen/.env (donde qwen CLI lo busca)
Copy-Item $envFile (Join-Path $QwenDir '.env') -Force
Write-Host "OK provider activo (~/.omnicoder/.env + ~/.qwen/.env)" -ForegroundColor Green

# Funcion helper: actualiza un settings.json con model.name + security.auth.selectedType=openai
function Update-SettingsFile {
    param([string]$Path, [string]$ModelName, [string]$Label)
    try {
        if (Test-Path $Path) {
            $json = Get-Content $Path -Raw | ConvertFrom-Json
        } else {
            $json = [PSCustomObject]@{}
        }
        if (-not $json.model) { $json | Add-Member -NotePropertyName model -NotePropertyValue ([PSCustomObject]@{}) -Force }
        $json.model | Add-Member -NotePropertyName name -NotePropertyValue $ModelName -Force
        if (-not $json.security) { $json | Add-Member -NotePropertyName security -NotePropertyValue ([PSCustomObject]@{}) -Force }
        if (-not $json.security.auth) { $json.security | Add-Member -NotePropertyName auth -NotePropertyValue ([PSCustomObject]@{}) -Force }
        $json.security.auth | Add-Member -NotePropertyName selectedType -NotePropertyValue 'openai' -Force
        $json | ConvertTo-Json -Depth 20 | Set-Content $Path -Encoding UTF8
        Write-Host "OK $Label : model.name=$ModelName, auth.selectedType=openai" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "Aviso: no se pudo actualizar $Label ($_)" -ForegroundColor Yellow
        return $false
    }
}

# Actualizar AMBOS settings.json (el visible en ~/.omnicoder/ y el real en ~/.qwen/)
Update-SettingsFile -Path $SettingsFile      -ModelName $cfg.Model -Label '~/.omnicoder/settings.json' | Out-Null
Update-SettingsFile -Path $QwenSettingsFile  -ModelName $cfg.Model -Label '~/.qwen/settings.json'      | Out-Null

# Eliminar OAuth cacheado de AMBOS sitios (sino prioriza sobre la API key)
foreach ($oauthCreds in @((Join-Path $OmniDir 'oauth_creds.json'), (Join-Path $QwenDir 'oauth_creds.json'))) {
    if (Test-Path $oauthCreds) {
        Remove-Item $oauthCreds -Force
        Write-Host "OK OAuth cacheado eliminado: $oauthCreds" -ForegroundColor Green
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
Write-Host "Listo! Arranca OmniCoder con:" -ForegroundColor Green
Write-Host "  omnicoder" -ForegroundColor Cyan
Write-Host "(OmniCoder lee automaticamente $activeEnv)"
