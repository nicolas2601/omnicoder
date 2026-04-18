#Requires -Version 5.1
<#
.SYNOPSIS
    OmniCoder CLI wrapper around `opencode` for Windows PowerShell.

.DESCRIPTION
    Mirrors bin/omnicoder (POSIX sh) on Windows. Keeps the upstream opencode
    binary intact (ADR-001) and exposes OmniCoder-branded UX:
      - OMNICODER_HOME env var (~/.omnicoder by default)
      - Provider detection (NVIDIA/MiniMax/DashScope/Anthropic/OpenAI)
      - OPENCODE_CONFIG indirection to ~/.omnicoder/opencode.jsonc
      - First-run ASCII banner
      - --omnicoder-version and `omnicoder doctor`

.NOTES
    Windows CI lessons applied (feedback_ci_windows_bat.md):
      #6 PATH mutations are done in install-windows.ps1, not here.
      #8 doctor may return 1 on a clean runner; callers should tolerate.
#>

$ErrorActionPreference = 'Stop'

# ---- constants -------------------------------------------------------------
$OmnicoderHomeDefault = Join-Path $HOME '.omnicoder'
if (-not $env:OMNICODER_HOME) { $env:OMNICODER_HOME = $OmnicoderHomeDefault }
$OmnicoderBannerFlag = Join-Path $env:OMNICODER_HOME '.banner-shown'
$OmnicoderUserConfig = Join-Path $env:OMNICODER_HOME 'opencode.jsonc'

# ---- version lookup --------------------------------------------------------
function Get-ScriptDir {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}

function Find-PackageJson {
    param([string]$ScriptDir)
    $candidates = @(
        (Join-Path $ScriptDir '..\packages\omnicoder\package.json'),
        (Join-Path $ScriptDir '..\share\omnicoder\package.json'),
        (Join-Path $env:OMNICODER_HOME 'package.json')
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) { return (Resolve-Path -LiteralPath $c).Path }
    }
    return $null
}

function Read-PkgVersion {
    param([string]$PkgPath)
    try {
        $json = Get-Content -LiteralPath $PkgPath -Raw | ConvertFrom-Json
        if ($json.version) { return [string]$json.version }
    } catch {
        # fall through
    }
    return 'unknown'
}

$scriptDir = Get-ScriptDir
$pkgJson = Find-PackageJson -ScriptDir $scriptDir
$OmnicoderVersion = if ($pkgJson) { Read-PkgVersion -PkgPath $pkgJson } else { 'unknown' }
$env:OMNICODER_VERSION = $OmnicoderVersion

# ---- provider detection ----------------------------------------------------
function Get-Providers {
    $providers = @()
    if ($env:NVIDIA_API_KEY)    { $providers += 'nvidia-nim' }
    if ($env:MINIMAX_API_KEY)   { $providers += 'minimax' }
    if ($env:DASHSCOPE_API_KEY) { $providers += 'dashscope' }
    if ($env:ANTHROPIC_API_KEY) { $providers += 'anthropic' }
    if ($env:OPENAI_API_KEY)    { $providers += 'openai' }
    return ($providers -join ' ')
}

$env:OMNICODER_PROVIDERS = Get-Providers

# ---- banner ----------------------------------------------------------------
function Write-Banner {
    if ($env:NO_COLOR -or -not [Environment]::UserInteractive) {
        Write-Host ("OmniCoder v{0}" -f $OmnicoderVersion)
        return
    }
    @'
   ___                  _ _____          _
  / _ \ _ __ ___  _ __ (_)  ___|__  _ __| | ___ _ __
 | | | | '_ ` _ \| '_ \| | |_ / _ \| '__| |/ _ \ '__|
 | |_| | | | | | | | | | |  _| (_) | |  | |  __/ |
  \___/|_| |_| |_|_| |_|_|_|  \___/|_|  |_|\___|_|
'@ | Write-Host
    Write-Host ("  OmniCoder v{0}  (opencode-powered)`n" -f $OmnicoderVersion)
}

function Show-BannerOnce {
    if (Test-Path -LiteralPath $OmnicoderBannerFlag) { return }
    try {
        New-Item -ItemType Directory -Path $env:OMNICODER_HOME -Force | Out-Null
        Write-Banner
        New-Item -ItemType File -Path $OmnicoderBannerFlag -Force | Out-Null
    } catch {
        # best-effort only
    }
}

# ---- doctor ----------------------------------------------------------------
function Invoke-Doctor {
    Write-Host ("OmniCoder doctor - v{0}`n" -f $OmnicoderVersion)
    $issues = 0

    $oc = Get-Command opencode -ErrorAction SilentlyContinue
    if ($oc) {
        Write-Host ("  [ok]   opencode binary       {0}" -f $oc.Source)
    } else {
        Write-Host "  [miss] opencode binary       not in PATH (run scripts\install-windows.ps1)"
        $issues++
    }

    $eg = Get-Command engram -ErrorAction SilentlyContinue
    if ($eg) {
        Write-Host ("  [ok]   engram binary         {0}" -f $eg.Source)
    } else {
        Write-Host "  [warn] engram binary         not in PATH (MCP memory disabled)"
    }

    if (Test-Path -LiteralPath $env:OMNICODER_HOME) {
        Write-Host ("  [ok]   OMNICODER_HOME        {0}" -f $env:OMNICODER_HOME)
    } else {
        Write-Host ("  [miss] OMNICODER_HOME        {0} (not created)" -f $env:OMNICODER_HOME)
        $issues++
    }

    if (Test-Path -LiteralPath $OmnicoderUserConfig) {
        Write-Host ("  [ok]   user config           {0}" -f $OmnicoderUserConfig)
    } else {
        Write-Host "  [info] user config           not present (using fork defaults)"
    }

    Write-Host "`nProviders:"
    foreach ($p in @(
        @{Name='NVIDIA_API_KEY';    Val=$env:NVIDIA_API_KEY},
        @{Name='MINIMAX_API_KEY';   Val=$env:MINIMAX_API_KEY},
        @{Name='DASHSCOPE_API_KEY'; Val=$env:DASHSCOPE_API_KEY},
        @{Name='ANTHROPIC_API_KEY'; Val=$env:ANTHROPIC_API_KEY},
        @{Name='OPENAI_API_KEY';    Val=$env:OPENAI_API_KEY}
    )) {
        $tag = if ($p.Val) { '[ok]  ' } else { '[--]  ' }
        $state = if ($p.Val) { 'set' } else { 'unset' }
        Write-Host ("  {0} {1,-20} {2}" -f $tag, $p.Name, $state)
    }

    if (-not $env:OMNICODER_PROVIDERS) {
        Write-Host "`n  [warn] no provider API keys detected - set at least one before running."
        $issues++
    }

    Write-Host ""
    if ($issues -eq 0) {
        Write-Host "Status: healthy"
        return 0
    }
    Write-Host ("Status: {0} issue(s) found" -f $issues)
    return 1
}

# ---- arg dispatch ----------------------------------------------------------
if ($args.Count -ge 1) {
    switch ($args[0]) {
        '--omnicoder-version' {
            $coreVersion = '(opencode not installed)'
            if (Get-Command opencode -ErrorAction SilentlyContinue) {
                try { $coreVersion = (& opencode --version 2>$null).Trim() } catch { $coreVersion = 'unknown' }
            }
            Write-Host ("omnicoder {0}" -f $OmnicoderVersion)
            Write-Host ("opencode  {0}" -f $coreVersion)
            exit 0
        }
        'doctor' {
            $rc = Invoke-Doctor
            exit $rc
        }
    }
}

if (-not (Get-Command opencode -ErrorAction SilentlyContinue)) {
    Write-Error "omnicoder: opencode is not installed. Run scripts\install-windows.ps1 first."
    exit 127
}

Show-BannerOnce

if (Test-Path -LiteralPath $OmnicoderUserConfig) {
    $env:OPENCODE_CONFIG = $OmnicoderUserConfig
}

# Forward remaining args to opencode, preserving exit code.
& opencode @args
exit $LASTEXITCODE
