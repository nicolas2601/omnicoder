#Requires -Version 5.1
<#
.SYNOPSIS
    Windows wrapper for packages/omnicoder/src/routing/preset.ts.

.DESCRIPTION
    Locates the TS entry point relative to this script (repo checkout or
    installed share/omnicoder/) and executes it via bun. Forwards every
    argument verbatim.
#>
[CmdletBinding()]
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)

$ErrorActionPreference = 'Stop'

function Resolve-ScriptDir {
    $p = $MyInvocation.MyCommand.Path
    while ($true) {
        $item = Get-Item -LiteralPath $p
        if ($item.PSIsContainer -or -not $item.Target) { break }
        $p = $item.Target
    }
    return Split-Path -Parent $p
}

$selfDir = Resolve-ScriptDir
$candidates = @(
    (Join-Path $selfDir '..\packages\omnicoder\src\routing\preset.ts'),
    (Join-Path $selfDir '..\share\omnicoder\routing\preset.ts'),
    (Join-Path $env:USERPROFILE '.omnicoder\scripts\routing\preset.ts')
)

$script = $null
foreach ($c in $candidates) {
    if (Test-Path -LiteralPath $c) { $script = (Resolve-Path -LiteralPath $c).Path; break }
}
if (-not $script) {
    Write-Error "omnicoder-routing: routing/preset.ts not found near $selfDir"
    exit 127
}

if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
    Write-Error "omnicoder-routing: bun is not in PATH. Install: irm bun.sh/install.ps1 | iex"
    exit 127
}

& bun $script @Args
exit $LASTEXITCODE
