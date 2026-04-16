# ============================================================
# OmniCoder - Patch Branding (Windows / PowerShell)
# Reemplaza "Qwen Code" por "OmniCoder" en la TUI del CLI
# y el ASCII logo QWEN por OMNI. Equivalente Windows de patch-branding.sh.
# Seguro: solo modifica strings de display, no logica.
# ============================================================
param([switch]$Quiet)

$ErrorActionPreference = 'Continue'

function Log {
    param([string]$Message, [string]$Color = 'Gray')
    if (-not $Quiet) { Write-Host $Message -ForegroundColor $Color }
}

# ── Detectar cli.js ──
$CliJs = $null
$candidates = @()

try {
    $qwenCmd = Get-Command qwen -ErrorAction SilentlyContinue
    if ($qwenCmd) {
        $qwenPath = $qwenCmd.Source
        $qwenDir = Split-Path -Parent $qwenPath
        $candidates += Join-Path $qwenDir 'cli.js'
        $candidates += Join-Path $qwenDir 'node_modules\@qwen-code\qwen-code\cli.js'
    }
} catch {}

try {
    $npmRoot = (npm root -g 2>$null).Trim()
    if ($npmRoot) { $candidates += Join-Path $npmRoot '@qwen-code\qwen-code\cli.js' }
} catch {}

$candidates += Join-Path $env:APPDATA 'npm\node_modules\@qwen-code\qwen-code\cli.js'
$candidates += Join-Path $env:USERPROFILE 'AppData\Roaming\npm\node_modules\@qwen-code\qwen-code\cli.js'

foreach ($c in $candidates) {
    if ($c -and (Test-Path $c)) { $CliJs = $c; break }
}

if (-not $CliJs) {
    Log "  [!!] No se encontro cli.js de Qwen Code. Patch de branding saltado." 'Yellow'
    exit 0
}

# ── Ya parcheado? ──
$content = Get-Content $CliJs -Raw -Encoding UTF8
if ($content -match '>_ OmniCoder' -and $content -match '(?<!QWEN)OMNI' -and $content -notmatch 'shortAsciiLogo\s*=\s*`[^`]*QWEN') {
    Log "  [OK] Branding ya parcheado (OmniCoder)" 'Green'
    exit 0
}

# ── Backup ──
$backup = "$CliJs.bak"
if (-not (Test-Path $backup)) {
    Copy-Item $CliJs $backup -Force
}

# ── Patch 1: ASCII logo QWEN -> OMNI ──
# Reemplaza el bloque `var shortAsciiLogo = \`...\`;` completo (multilinea, no-greedy).
$omniLogo = @'
var shortAsciiLogo = `
 ██████╗ ███╗   ███╗███╗   ██╗██╗
██╔═══██╗████╗ ████║████╗  ██║██║
██║   ██║██╔████╔██║██╔██╗ ██║██║
██║   ██║██║╚██╔╝██║██║╚██╗██║██║
╚██████╔╝██║ ╚═╝ ██║██║ ╚████║██║
 ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═══╝╚═╝
`;
'@

# Regex que acepta cualquier contenido entre backticks (incluye newlines).
# Uso Regex.Replace con string literal (escapar $ que es metachar de substitucion).
$logoPattern = 'var shortAsciiLogo\s*=\s*`[^`]*`;'
$omniLogoEscaped = $omniLogo -replace '\$', '$$$$'
$newContent = [regex]::Replace($content, $logoPattern, $omniLogoEscaped, [System.Text.RegularExpressions.RegexOptions]::Singleline)

# ── Patch 2-5: strings planos ──
$replacements = @(
    @{ From = '>_ Qwen Code"';                            To = '>_ OmniCoder"' },
    @{ From = 'You are Qwen Code';                        To = 'You are OmniCoder' },
    @{ From = 'using Qwen Code';                          To = 'using OmniCoder' },
    @{ From = 'this Qwen Code session';                   To = 'this OmniCoder session' },
    @{ From = 'To continue using Qwen Code';              To = 'To continue using OmniCoder' },
    @{ From = '"X-OpenRouter-Title": "Qwen Code"';        To = '"X-OpenRouter-Title": "OmniCoder"' },
    @{ From = 'running Qwen Code in your home directory'; To = 'running OmniCoder in your home directory' },
    @{ From = 'running Qwen Code in the root directory';  To = 'running OmniCoder in the root directory' }
)

foreach ($r in $replacements) {
    $newContent = $newContent.Replace($r.From, $r.To)
}

# ── Escribir sin BOM ──
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($CliJs, $newContent, $utf8NoBom)

# ── Verificar ──
$verify = Get-Content $CliJs -Raw -Encoding UTF8
if ($verify -match '>_ OmniCoder') {
    Log "  [OK] Branding parcheado: Qwen Code -> OmniCoder (logo + texto)" 'Green'
} else {
    Log "  [!!] Patch de branding fallo - restaurando backup" 'Yellow'
    Copy-Item $backup $CliJs -Force
    exit 1
}
