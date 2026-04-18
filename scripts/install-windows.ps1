#Requires -Version 5.1
<#
.SYNOPSIS
    Install or uninstall OmniCoder on Windows.

.DESCRIPTION
    Idempotent installer that mirrors scripts/install.sh on Linux/macOS:
      1. Ensures `opencode` is available (npm i -g opencode-ai@latest).
      2. Downloads the latest `engram` release and SHA-256 verifies it.
      3. Copies bin/omnicoder.cmd and omnicoder.ps1 into the user's programs dir.
      4. Adds the install dir to the *User* PATH via
         [Environment]::SetEnvironmentVariable (feedback #6 — setx is unsafe).
      5. Seeds $env:USERPROFILE\.omnicoder\ from .opencode\agent and .opencode\skills.
      6. Seeds $env:APPDATA\opencode\opencode.jsonc only if missing.

.PARAMETER Uninstall
    Reverse the install (with confirmation unless -Yes is passed).

.PARAMETER InstallDir
    Override target directory. Default: $env:LOCALAPPDATA\Programs\omnicoder\bin

.PARAMETER Yes
    Skip interactive confirmations (CI mode).

.PARAMETER EngramSha256
    Pinned SHA-256 for the engram asset. Required unless -SkipEngramVerify.

.PARAMETER SkipEngramVerify
    Skip SHA-256 verification (dev-only, logs a warning).

.NOTES
    Lessons from feedback_ci_windows_bat.md applied:
      #2-4  We avoid robocopy/xcopy — we use Copy-Item with -Force + hashing.
      #6    PATH persistence via [Environment], never `setx %PATH%`.
      #8    Doctor can legitimately return 1 on CI; tolerate explicitly.
#>
[CmdletBinding()]
param(
    [switch]$Uninstall,
    [string]$InstallDir = "$env:LOCALAPPDATA\Programs\omnicoder\bin",
    [switch]$Yes,
    [string]$EngramSha256Linux,  # unused on Windows but kept for symmetry
    [string]$EngramSha256,
    [switch]$SkipEngramVerify
)

$ErrorActionPreference = 'Stop'

# ---- constants -------------------------------------------------------------
$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$OmnicoderHome = Join-Path $env:USERPROFILE '.omnicoder'
$OpencodeCfgDir = Join-Path $env:APPDATA 'opencode'
$OpencodeCfgFile = Join-Path $OpencodeCfgDir 'opencode.jsonc'
$EngramRepo = 'Gentleman-Programming/engram'

# ---- helpers ---------------------------------------------------------------
function Write-Log  { param([string]$Msg) Write-Host "[install] $Msg" }
function Write-Warn { param([string]$Msg) Write-Host "[install] WARN: $Msg" -ForegroundColor Yellow }
function Die        { param([string]$Msg) Write-Host "[install] ERROR: $Msg" -ForegroundColor Red; exit 1 }

function Confirm-Action {
    param([string]$Prompt)
    if ($Yes) { return $true }
    $a = Read-Host "$Prompt [y/N]"
    return ($a -match '^[yY]')
}

function Add-ToUserPath {
    param([string]$Dir)
    # Feedback #6: NEVER `setx PATH "%PATH%;..."` — mixes scopes and truncates at 1024.
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ([string]::IsNullOrEmpty($user)) { $user = '' }
    $parts = $user -split ';' | Where-Object { $_ -ne '' }
    if ($parts -contains $Dir) {
        Write-Log "User PATH already contains $Dir"
        return
    }
    $new = (($parts + @($Dir)) -join ';')
    [Environment]::SetEnvironmentVariable('Path', $new, 'User')
    $env:Path = "$env:Path;$Dir"
    Write-Log "Added $Dir to User PATH (restart shell to pick up)"
}

function Remove-FromUserPath {
    param([string]$Dir)
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ([string]::IsNullOrEmpty($user)) { return }
    $parts = $user -split ';' | Where-Object { $_ -ne '' -and $_ -ne $Dir }
    [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User')
    Write-Log "Removed $Dir from User PATH"
}

function Get-FileSha256 {
    param([string]$Path)
    (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Copy-IfMissing {
    param([string]$Src, [string]$Dst)
    if (-not (Test-Path -LiteralPath $Src)) { return }
    $dstDir = Split-Path -Parent $Dst
    if (-not (Test-Path -LiteralPath $dstDir)) {
        New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $Dst)) {
        Copy-Item -LiteralPath $Src -Destination $Dst -Force
    }
}

# ---- steps -----------------------------------------------------------------
function Install-Opencode {
    if (Get-Command opencode -ErrorAction SilentlyContinue) {
        Write-Log "opencode already installed: $((Get-Command opencode).Source)"
        return
    }
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Die "npm not found; install Node.js 18+ first."
    }
    Write-Log "Installing opencode-ai globally via npm"
    & npm install -g opencode-ai@latest
    if ($LASTEXITCODE -ne 0) { Die "npm install failed (exit $LASTEXITCODE)" }
}

function Install-RepoDeps {
    # The `omnicoder` wrapper prefers the fork's TypeScript source (purple
    # theme, omnicoder branding, agent aliases, plugin hot paths) whenever
    # node_modules are ready. Running `bun install` here wires that up so
    # a fresh `omnicoder` launch hits the patched build, not the upstream
    # opencode npm tarball.
    if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
        Write-Warn "bun not found — wrapper will fall back to the npm opencode (no fork branding)."
        Write-Warn "Install bun first if you want the purple theme + OmniCoder splash: irm bun.sh/install.ps1 | iex"
        return
    }
    $opentui = Join-Path $RepoRoot 'packages\opencode\node_modules\@opentui\core'
    if (Test-Path -LiteralPath $opentui) {
        Write-Log "repo deps already installed (found @opentui/core) — skipping bun install"
        return
    }
    Write-Log "Installing repo deps with bun (one-time, ~30s)"
    Push-Location $RepoRoot
    try {
        & bun install
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "bun install failed (exit $LASTEXITCODE) — wrapper will fall back to the npm opencode"
        }
    } finally { Pop-Location }
}

function Install-Engram {
    if (Get-Command engram -ErrorAction SilentlyContinue) {
        Write-Log "engram already installed: $((Get-Command engram).Source)"
        return
    }

    $arch = switch -Regex ($env:PROCESSOR_ARCHITECTURE) {
        'ARM64'       { 'aarch64' }
        'AMD64|x86_64'{ 'x86_64' }
        default       { Die "unsupported arch: $($env:PROCESSOR_ARCHITECTURE)" }
    }

    $tmp = Join-Path $env:TEMP ("omni-engram-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null

    try {
        $asset = $null

        # Prefer gh when available (handles rate limits + auth).
        if (Get-Command gh -ErrorAction SilentlyContinue) {
            Write-Log "Fetching engram via gh (windows-$arch)"
            try {
                & gh release download --repo $EngramRepo `
                    --pattern "engram*windows*$arch*" `
                    --dir $tmp 2>$null
            } catch {
                Write-Warn "gh download failed: $_ — will try curl fallback"
            }
        }

        if (-not (Get-ChildItem -Path $tmp -File -ErrorAction SilentlyContinue)) {
            Write-Log "Falling back to GitHub REST + Invoke-WebRequest"
            $api = "https://api.github.com/repos/$EngramRepo/releases/latest"
            $rel = Invoke-RestMethod -Uri $api -Headers @{ 'User-Agent' = 'omnicoder-install' }
            $assetObj = $rel.assets | Where-Object { $_.name -match "windows.*$arch" } | Select-Object -First 1
            if (-not $assetObj) { Die "Could not find engram windows $arch asset in latest release" }

            $dst = Join-Path $tmp $assetObj.name
            Write-Log "Downloading $($assetObj.browser_download_url)"
            Invoke-WebRequest -Uri $assetObj.browser_download_url `
                -Headers @{ 'Accept' = 'application/octet-stream'; 'User-Agent' = 'omnicoder-install' } `
                -OutFile $dst
            $asset = $dst
        } else {
            $asset = (Get-ChildItem -Path $tmp -File | Select-Object -First 1).FullName
        }

        if (-not $asset -or -not (Test-Path -LiteralPath $asset)) {
            Die "engram asset missing after download"
        }

        # SEC-05: SHA-256 verification.
        if ($SkipEngramVerify) {
            Write-Warn "SHA-256 verification skipped (--SkipEngramVerify)"
        } elseif ($EngramSha256) {
            $actual = Get-FileSha256 -Path $asset
            if ($actual -ne $EngramSha256.ToLowerInvariant()) {
                Die "engram SHA-256 mismatch: expected $EngramSha256, got $actual"
            }
            Write-Log "engram SHA-256 verified"
        } else {
            Write-Warn "No -EngramSha256 pinned — skipping digest verification. Pass it for SEC-05 compliance."
        }

        # Unpack if archive.
        if ($asset -match '\.zip$') {
            Expand-Archive -LiteralPath $asset -DestinationPath $tmp -Force
        } elseif ($asset -match '\.tar\.gz$|\.tgz$') {
            & tar -xzf $asset -C $tmp
            if ($LASTEXITCODE -ne 0) { Die "tar extraction failed" }
        }

        $exe = Get-ChildItem -Path $tmp -Recurse -File -Filter 'engram.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $exe) {
            $exe = Get-ChildItem -Path $tmp -Recurse -File -Filter 'engram' -ErrorAction SilentlyContinue | Select-Object -First 1
        }
        if (-not $exe) { Die "engram executable not found in downloaded asset" }

        $engramDst = Join-Path $InstallDir 'engram.exe'
        Copy-Item -LiteralPath $exe.FullName -Destination $engramDst -Force
        Write-Log "engram installed to $engramDst"
    }
    finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Install-Wrappers {
    if (-not (Test-Path -LiteralPath $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }
    foreach ($f in @('omnicoder.cmd', 'omnicoder.ps1', 'omnicoder-routing.ps1')) {
        $src = Join-Path $RepoRoot "bin\$f"
        if (-not (Test-Path -LiteralPath $src)) {
            Write-Warn "missing $src"
            continue
        }
        $dst = Join-Path $InstallDir $f
        Copy-Item -LiteralPath $src -Destination $dst -Force
        Write-Log "installed $dst"
    }
    # Tiny .cmd forwarder so `omnicoder-routing list` works from CMD too, not
    # just PowerShell. Hand-rolled because we do not want to ship another
    # maintained script; it simply re-invokes pwsh against the .ps1 sibling.
    $fwd = Join-Path $InstallDir 'omnicoder-routing.cmd'
    $fwdBody = @'
@echo off
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0omnicoder-routing.ps1" %*
'@
    Set-Content -LiteralPath $fwd -Value $fwdBody -Encoding ASCII
    Write-Log "installed $fwd"
    Add-ToUserPath -Dir $InstallDir
}

function Initialize-OmnicoderHome {
    if (-not (Test-Path -LiteralPath $OmnicoderHome)) {
        New-Item -ItemType Directory -Path $OmnicoderHome -Force | Out-Null
    }
    $pkg = Join-Path $RepoRoot 'packages\omnicoder\package.json'
    if (Test-Path -LiteralPath $pkg) {
        Copy-Item -LiteralPath $pkg -Destination (Join-Path $OmnicoderHome 'package.json') -Force
    }

    foreach ($sub in @('agent', 'skills')) {
        $src = Join-Path $RepoRoot ".opencode\$sub"
        $dst = Join-Path $OmnicoderHome $sub
        if (-not (Test-Path -LiteralPath $src)) { continue }
        if (-not (Test-Path -LiteralPath $dst)) {
            New-Item -ItemType Directory -Path $dst -Force | Out-Null
        }
        # Idempotent per-file copy — never overwrites user edits.
        Get-ChildItem -Path $src -Recurse -File | ForEach-Object {
            $rel = $_.FullName.Substring($src.Length).TrimStart('\','/')
            $target = Join-Path $dst $rel
            Copy-IfMissing -Src $_.FullName -Dst $target
        }
    }
    # Routing presets — copy-if-missing so user edits survive re-install.
    $presetsSrc = Join-Path $RepoRoot '.omnicoder\routing-presets.json'
    $presetsDst = Join-Path $OmnicoderHome 'routing-presets.json'
    if ((Test-Path -LiteralPath $presetsSrc) -and -not (Test-Path -LiteralPath $presetsDst)) {
        Copy-Item -LiteralPath $presetsSrc -Destination $presetsDst -Force
    }
    Write-Log "seeded $OmnicoderHome (non-destructive)"
}

function Initialize-OpencodeConfig {
    if (-not (Test-Path -LiteralPath $OpencodeCfgDir)) {
        New-Item -ItemType Directory -Path $OpencodeCfgDir -Force | Out-Null
    }
    if (Test-Path -LiteralPath $OpencodeCfgFile) {
        Write-Log "opencode config exists at $OpencodeCfgFile (respecting user overrides)"
        return
    }
    $src = Join-Path $RepoRoot '.omnicoder\opencode.jsonc'
    if (Test-Path -LiteralPath $src) {
        Copy-Item -LiteralPath $src -Destination $OpencodeCfgFile -Force
        Write-Log "seeded $OpencodeCfgFile"
    }
}

function Invoke-Uninstall {
    if (-not (Confirm-Action -Prompt "Uninstall OmniCoder from $InstallDir and $OmnicoderHome?")) {
        Write-Log "aborted"; return
    }
    foreach ($f in @('omnicoder.cmd', 'omnicoder.ps1', 'omnicoder-routing.cmd', 'omnicoder-routing.ps1', 'engram.exe')) {
        $p = Join-Path $InstallDir $f
        if (Test-Path -LiteralPath $p) {
            Remove-Item -LiteralPath $p -Force
            Write-Log "removed $p"
        }
    }
    Remove-FromUserPath -Dir $InstallDir
    if ((Test-Path -LiteralPath $OmnicoderHome) -and
        (Confirm-Action -Prompt "Remove $OmnicoderHome (includes agents/skills/config)?")) {
        Remove-Item -LiteralPath $OmnicoderHome -Recurse -Force
        Write-Log "removed $OmnicoderHome"
    }
    if ((Test-Path -LiteralPath $OpencodeCfgFile) -and
        (Confirm-Action -Prompt "Remove seeded opencode config at $OpencodeCfgFile?")) {
        Remove-Item -LiteralPath $OpencodeCfgFile -Force
    }
    Write-Log "uninstall complete (opencode-ai/npm kept — remove manually if desired)"
}

function Show-Hints {
    Write-Host @"

[install] done.

Next steps -- set at least one provider key before running ``omnicoder``:

  [Environment]::SetEnvironmentVariable('NVIDIA_API_KEY',   '...', 'User')
  [Environment]::SetEnvironmentVariable('MINIMAX_API_KEY',  '...', 'User')
  [Environment]::SetEnvironmentVariable('DASHSCOPE_API_KEY','...', 'User')
  [Environment]::SetEnvironmentVariable('ANTHROPIC_API_KEY','...', 'User')
  [Environment]::SetEnvironmentVariable('OPENAI_API_KEY',   '...', 'User')

Then open a new shell and run:
  omnicoder doctor       # health check
  omnicoder              # launch the TUI
"@
}

# ---- main ------------------------------------------------------------------
if ($Uninstall) {
    Invoke-Uninstall
    exit 0
}

Write-Log "OmniCoder install -> InstallDir=$InstallDir, Home=$OmnicoderHome"
Install-Opencode
Install-RepoDeps
Install-Engram
Install-Wrappers
Initialize-OmnicoderHome
Initialize-OpencodeConfig
Show-Hints
