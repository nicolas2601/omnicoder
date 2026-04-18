#Requires -Version 5.1
<#
.SYNOPSIS
    One-shot bootstrap for a fresh Windows machine. Goes from zero to a working
    OmniCoder v5 install with NVIDIA NIM configured, no prior state assumed.

.DESCRIPTION
    Safe-by-default. Every destructive step prompts before running unless -Yes.
    Never touches system-level settings; only the current user profile, user
    PATH, and user-level npm globals.

    Flow (each step is skipped if already satisfied):
      1. Check Windows version + PowerShell >= 5.1.
      2. Ensure winget is available (guides to Store install if not).
      3. Install or upgrade: Node.js LTS, Git, GitHub CLI (winget, user scope).
      4. Run `gh auth login` if not authenticated.
      5. Purge legacy v4 state: @qwen-code/qwen-code, old opencode-ai, stale
         folders (~\.qwen, ~\.omnicoder, %APPDATA%\opencode,
         %LOCALAPPDATA%\Programs\omnicoder). Confirms before each deletion
         unless -Yes. Backs up ~\.omnicoder\memory to %TEMP% first.
      6. Clone (or update) nicolas2601/omnicoder into ~\omnicoder-v5.
      7. Run scripts\install-windows.ps1 -Yes -SkipEngramVerify.
      8. Prompt for NVIDIA_API_KEY (masked), persist to User scope, export both
         NVIDIA_API_KEY and OPENAI_API_KEY (same value, needed by the NIM
         OpenAI-compat adapter in opencode.jsonc).
      9. Run `omnicoder doctor` in a fresh child PowerShell so the new PATH and
         env vars are picked up, then report the final status.

.PARAMETER Yes
    Skip every interactive confirmation. Use only on disposable machines.

.PARAMETER SkipCleanup
    Do NOT remove any v4 state. Keeps Qwen Code, old opencode, ~\.qwen, etc.
    Useful if the user explicitly wants a side-by-side install.

.PARAMETER KeepMemory
    Preserve ~\.omnicoder\memory\*. Copies it to %TEMP%\omnicoder-memory-backup
    before the purge AND restores it into the new install. Default: ON.

.PARAMETER NvidiaApiKey
    Provide the NVIDIA NIM key non-interactively (useful for scripted
    provisioning). When absent, the script prompts with Read-Host -AsSecureString.

.PARAMETER RepoDir
    Override target for the v5 clone. Default: $env:USERPROFILE\omnicoder-v5

.PARAMETER DryRun
    Print every destructive action but do not execute. Nothing on disk changes.
    Safe for a "show me what you would do" walkthrough.

.EXAMPLE
    # Typical end-user flow — interactive, safe, keeps memory.
    pwsh .\scripts\bootstrap-windows.ps1

.EXAMPLE
    # Fully unattended reinstall (CI / disposable VM).
    pwsh .\scripts\bootstrap-windows.ps1 -Yes -NvidiaApiKey $env:NVIDIA_API_KEY

.NOTES
    - Never runs as Administrator. If elevated, warns and exits — installer
      expects user scope so globals don't land in Program Files.
    - Does not touch the system registry other than User-scope env vars via
      [Environment]::SetEnvironmentVariable('...', 'User').
    - Designed to be safely re-runnable: every step is idempotent.
#>
[CmdletBinding()]
param(
    [switch]$Yes,
    [switch]$SkipCleanup,
    [switch]$KeepMemory = $true,
    [string]$NvidiaApiKey,
    [string]$RepoDir = "$env:USERPROFILE\omnicoder-v5",
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$script:LogFile = Join-Path $env:TEMP "omnicoder-bootstrap-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# ---- presentation helpers --------------------------------------------------
function Write-Step  { param([int]$N, [string]$Msg) Write-Host "`n[$N/9] $Msg" -ForegroundColor Cyan }
function Write-Info  { param([string]$Msg) Write-Host "  $Msg" }
function Write-Ok    { param([string]$Msg) Write-Host "  [ok]   $Msg" -ForegroundColor Green }
function Write-Warn2 { param([string]$Msg) Write-Host "  [warn] $Msg" -ForegroundColor Yellow }
function Die         { param([string]$Msg) Write-Host "[bootstrap] ERROR: $Msg" -ForegroundColor Red; exit 1 }
function Ask         {
    param([string]$Prompt)
    if ($Yes) { return $true }
    $a = Read-Host "  $Prompt [y/N]"
    return ($a -match '^[yY]')
}

function Invoke-Destructive {
    param([string]$Label, [scriptblock]$Action)
    if ($DryRun) { Write-Info "(dry-run) would: $Label"; return }
    Write-Info $Label
    & $Action
}

# ---- sanity checks ---------------------------------------------------------
function Assert-Preconditions {
    Write-Step 1 'Sanity checks'

    $isAdmin = ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
            [Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) {
        Die "You are running as Administrator. Re-run this script from a normal user PowerShell so that npm globals land in your user profile instead of Program Files."
    }
    Write-Ok "Non-admin session"

    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Die "PowerShell $($PSVersionTable.PSVersion) is too old. Need 5.1+."
    }
    Write-Ok "PowerShell $($PSVersionTable.PSVersion)"

    $os = [System.Environment]::OSVersion
    Write-Ok "OS: $($os.VersionString)"
    Write-Info "Log will be written to $script:LogFile"
}

# ---- winget ----------------------------------------------------------------
function Ensure-Winget {
    Write-Step 2 'winget availability'
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Ok "winget present"
        return
    }
    Write-Warn2 "winget is missing. On Windows 10/11, install 'App Installer' from the Microsoft Store:"
    Write-Info "  https://apps.microsoft.com/detail/9NBLGGH4NNS1"
    Write-Info "Re-run this script after install."
    Die "winget not available"
}

# ---- package installs ------------------------------------------------------
function Ensure-WingetPackage {
    param([string]$Id, [string]$Label)
    # `winget list` returns non-zero when the package is not installed, so we
    # parse output ourselves rather than relying on exit codes.
    $present = $false
    try {
        $out = winget list --id $Id --source winget --accept-source-agreements 2>$null
        if ($out -and ($out -match [regex]::Escape($Id))) { $present = $true }
    } catch { $present = $false }

    if ($present) {
        Write-Ok "$Label already installed"
        if ($DryRun) { return }
        # Best-effort upgrade, ignore "no update" exit codes.
        try { winget upgrade --id $Id --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null } catch {}
        return
    }
    Invoke-Destructive "Installing $Label via winget" {
        winget install --id $Id --silent --accept-package-agreements --accept-source-agreements --scope user
        if ($LASTEXITCODE -ne 0) { Die "winget install $Id failed (exit $LASTEXITCODE)" }
    }
}

function Ensure-Prerequisites {
    Write-Step 3 'Prerequisites: Node.js LTS, Git, GitHub CLI'
    Ensure-WingetPackage -Id 'OpenJS.NodeJS.LTS' -Label 'Node.js LTS'
    Ensure-WingetPackage -Id 'Git.Git' -Label 'Git'
    Ensure-WingetPackage -Id 'GitHub.cli' -Label 'GitHub CLI'

    # Fresh installs place node/git in User-scope dirs that aren't in *this*
    # shell's PATH yet. Refresh PATH for the rest of the bootstrap.
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user    = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = ($machine, $user -join ';').TrimEnd(';')
}

# ---- gh auth ---------------------------------------------------------------
function Ensure-GhAuth {
    Write-Step 4 'GitHub authentication'
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Die "gh not found after install. Close this PowerShell and open a new one, then re-run."
    }
    $status = gh auth status 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "gh already authenticated"
        return
    }
    Write-Info "Launching 'gh auth login' (browser flow)..."
    if ($DryRun) { Write-Info "(dry-run) would: gh auth login -h github.com -p https -w"; return }
    gh auth login -h github.com -p https -w
    if ($LASTEXITCODE -ne 0) { Die "gh auth login failed" }
}

# ---- legacy cleanup --------------------------------------------------------
function Backup-Memory {
    $src = Join-Path $env:USERPROFILE '.omnicoder\memory'
    if (-not (Test-Path -LiteralPath $src)) { return $null }
    $dst = Join-Path $env:TEMP "omnicoder-memory-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    if ($DryRun) { Write-Info "(dry-run) would backup $src -> $dst"; return $dst }
    New-Item -ItemType Directory -Path $dst -Force | Out-Null
    Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
    Write-Ok "Memory backed up to $dst"
    return $dst
}

function Restore-Memory {
    param([string]$BackupDir)
    if (-not $BackupDir) { return }
    if (-not (Test-Path -LiteralPath $BackupDir)) { return }
    $target = Join-Path $env:USERPROFILE '.omnicoder\memory'
    $srcInside = Join-Path $BackupDir 'memory'
    if (Test-Path -LiteralPath $srcInside) { $src = $srcInside } else { $src = $BackupDir }
    if ($DryRun) { Write-Info "(dry-run) would restore $src -> $target"; return }
    if (-not (Test-Path -LiteralPath $target)) { New-Item -ItemType Directory -Path $target -Force | Out-Null }
    Copy-Item -LiteralPath (Join-Path $src '*') -Destination $target -Recurse -Force -ErrorAction SilentlyContinue
    Write-Ok "Memory restored from $BackupDir"
}

function Remove-LegacyState {
    Write-Step 5 'Purge v4 / Qwen Code / stale state'
    if ($SkipCleanup) { Write-Warn2 "SkipCleanup set; leaving old state in place"; return $null }

    $backup = $null
    if ($KeepMemory) { $backup = Backup-Memory }

    $npmTargets = @(
        @{ Name = '@qwen-code/qwen-code'; Why = 'v4 Qwen Code CLI (replaced by opencode)' },
        @{ Name = 'opencode-ai';          Why = 'reinstalled fresh by install-windows.ps1' }
    )
    foreach ($t in $npmTargets) {
        if (-not (Get-Command npm -ErrorAction SilentlyContinue)) { break }
        if (Ask "Uninstall npm global '$($t.Name)' ($($t.Why))?") {
            Invoke-Destructive "npm uninstall -g $($t.Name)" {
                & npm uninstall -g $t.Name 2>&1 | Out-Null
            }
        }
    }

    $dirTargets = @(
        "$env:USERPROFILE\.qwen",
        "$env:USERPROFILE\.omnicoder",
        "$env:APPDATA\opencode",
        "$env:LOCALAPPDATA\Programs\omnicoder"
    )
    foreach ($d in $dirTargets) {
        if (-not (Test-Path -LiteralPath $d)) { continue }
        if (Ask "Delete $d?") {
            Invoke-Destructive "Remove-Item -Recurse -Force $d" {
                Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    # Clean dead omnicoder entries from User PATH. Never touch Machine PATH.
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($user) {
        $parts = $user -split ';' | Where-Object { $_ -ne '' }
        $keep  = $parts | Where-Object { $_ -notmatch 'Programs\\omnicoder' }
        if ($keep.Count -ne $parts.Count) {
            Invoke-Destructive "Prune $($parts.Count - $keep.Count) stale omnicoder entries from User PATH" {
                [Environment]::SetEnvironmentVariable('Path', ($keep -join ';'), 'User')
            }
        }
    }

    return $backup
}

# ---- clone + install -------------------------------------------------------
function Get-OmnicoderRepo {
    Write-Step 6 "Clone or update OmniCoder v5 into $RepoDir"
    if (Test-Path -LiteralPath (Join-Path $RepoDir '.git')) {
        Invoke-Destructive "git pull in $RepoDir" {
            Push-Location $RepoDir
            try { git pull --ff-only }
            finally { Pop-Location }
        }
    } else {
        Invoke-Destructive "git clone nicolas2601/omnicoder -> $RepoDir" {
            git clone https://github.com/nicolas2601/omnicoder.git $RepoDir
            if ($LASTEXITCODE -ne 0) { Die "git clone failed" }
        }
    }
}

function Invoke-Installer {
    Write-Step 7 'Run install-windows.ps1'
    $installer = Join-Path $RepoDir 'scripts\install-windows.ps1'
    if (-not (Test-Path -LiteralPath $installer)) { Die "Installer not found at $installer" }
    if ($DryRun) { Write-Info "(dry-run) would: pwsh $installer -Yes -SkipEngramVerify"; return }

    # Bypass execution policy for this process only, not system-wide.
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
    & pwsh -NoProfile -File $installer -Yes -SkipEngramVerify
    if ($LASTEXITCODE -ne 0) { Die "install-windows.ps1 exited with $LASTEXITCODE" }
}

# ---- API key ---------------------------------------------------------------
function Set-ApiKeys {
    Write-Step 8 'Configure NVIDIA NIM API key'
    $key = $NvidiaApiKey
    if (-not $key) {
        Write-Info "Get a free key at https://build.nvidia.com (40 rpm, works 100 years)."
        $secure = Read-Host "  Paste your NVIDIA API key (input hidden)" -AsSecureString
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        try {
            $key = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        } finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
    }
    if (-not $key -or $key.Trim().Length -lt 20) {
        Write-Warn2 "No valid key provided; skipping. Set later with:"
        Write-Info "  [Environment]::SetEnvironmentVariable('NVIDIA_API_KEY','nvapi-...','User')"
        return
    }
    if ($DryRun) { Write-Info "(dry-run) would persist NVIDIA_API_KEY / OPENAI_API_KEY to User scope"; return }
    [Environment]::SetEnvironmentVariable('NVIDIA_API_KEY', $key, 'User')
    [Environment]::SetEnvironmentVariable('OPENAI_API_KEY', $key, 'User')
    $env:NVIDIA_API_KEY = $key
    $env:OPENAI_API_KEY = $key
    Write-Ok "NVIDIA_API_KEY + OPENAI_API_KEY persisted (User scope)"
}

# ---- verification ----------------------------------------------------------
function Invoke-Doctor {
    Write-Step 9 'Verify install with omnicoder doctor'
    if ($DryRun) { Write-Info "(dry-run) would: omnicoder doctor"; return }
    # Use a child pwsh so the refreshed User PATH and env vars are visible.
    $child = @"
`$machine = [Environment]::GetEnvironmentVariable('Path','Machine')
`$user    = [Environment]::GetEnvironmentVariable('Path','User')
`$env:Path = (`$machine, `$user -join ';').TrimEnd(';')
omnicoder doctor
"@
    pwsh -NoProfile -Command $child
    if ($LASTEXITCODE -ne 0) {
        Write-Warn2 "doctor returned $LASTEXITCODE. Re-open a new PowerShell and run 'omnicoder doctor' to confirm."
    }
}

# ---- main ------------------------------------------------------------------
try {
    Start-Transcript -Path $script:LogFile -Force | Out-Null
    Write-Host "OmniCoder v5 — Windows bootstrap" -ForegroundColor Magenta
    if ($DryRun) { Write-Host "DRY-RUN mode: no changes will be made." -ForegroundColor Yellow }
    if ($Yes)    { Write-Host "Unattended mode: all prompts auto-confirmed." -ForegroundColor Yellow }

    Assert-Preconditions
    Ensure-Winget
    Ensure-Prerequisites
    Ensure-GhAuth
    $memoryBackup = Remove-LegacyState
    Get-OmnicoderRepo
    Invoke-Installer
    if ($memoryBackup) { Restore-Memory -BackupDir $memoryBackup }
    Set-ApiKeys
    Invoke-Doctor

    Write-Host "`nDone. Open a NEW PowerShell window and run:" -ForegroundColor Green
    Write-Host "  omnicoder" -ForegroundColor Green
    Write-Host "Log: $script:LogFile" -ForegroundColor DarkGray
}
catch {
    Write-Host "`n[bootstrap] FAILED: $_" -ForegroundColor Red
    Write-Host "Log: $script:LogFile" -ForegroundColor DarkGray
    exit 1
}
finally {
    try { Stop-Transcript | Out-Null } catch {}
}
