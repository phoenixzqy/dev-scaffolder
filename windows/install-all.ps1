# ============================================================================
# Windows Dev-Machine Scaffolder — Orchestrator
# Installs every tool (in the right order) and deploys every config.
#
# Usage:
#   .\install-all.ps1                          # run everything
#   .\install-all.ps1 -Only nvim,starship      # run only matching tool scripts
#   .\install-all.ps1 -Skip windows-terminal   # skip specific tool scripts
#   .\install-all.ps1 -DryRun                  # print what would run
#   irm <RAW_URL>/install-all.ps1 | iex        # one-shot from remote
# ============================================================================
#Requires -Version 5.1
[CmdletBinding()]
param(
    [string[]]$Only,
    [string[]]$Skip,
    [switch]  $DryRun
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\lib\common.ps1"

Write-Host @"

╔══════════════════════════════════════════════════════════╗
║   Windows Dev-Machine Scaffolder                         ║
║   one-click reproducible terminal setup                  ║
╚══════════════════════════════════════════════════════════╝
"@ -ForegroundColor Magenta

$toolsDir = Join-Path $PSScriptRoot "tools"
$scripts  = Get-ChildItem -Path $toolsDir -Filter "*.ps1" | Sort-Object Name

# Normalize list-style args so both forms work:
#   pwsh -File   install-all.ps1 -Only nvim,starship   (single comma-joined string)
#   pwsh -Command install-all.ps1 -Only nvim,starship  (real array)
function Normalize-NameList([string[]]$xs) {
    if (-not $xs) { return @() }
    $xs | ForEach-Object { $_ -split '[,;\s]+' } |
          Where-Object { $_ } |
          ForEach-Object { $_.ToLowerInvariant() }
}
$OnlySet = Normalize-NameList $Only
$SkipSet = Normalize-NameList $Skip

# Short logical name derived from filename: "50-starship.ps1" -> "starship"
function Get-ToolName([System.IO.FileInfo]$f) {
    ($f.BaseName -replace '^\d+-', '').ToLowerInvariant()
}

$plan = foreach ($s in $scripts) {
    $name = Get-ToolName $s
    $include = $true
    if ($OnlySet.Count -gt 0 -and $OnlySet -notcontains $name) { $include = $false }
    if ($SkipSet -contains $name)                              { $include = $false }
    [pscustomobject]@{ Name = $name; Path = $s.FullName; Run = $include }
}

Write-Host ""
Write-Host "Plan:" -ForegroundColor Yellow
$plan | ForEach-Object {
    $flag  = if ($_.Run) { "[+]" } else { "[ ]" }
    $color = if ($_.Run) { "Green" } else { "DarkGray" }
    Write-Host ("  {0} {1}" -f $flag, $_.Name) -ForegroundColor $color
}

if ($DryRun) { Write-Host "`n(dry run — no scripts executed)" -ForegroundColor Yellow; return }

$failed = @()
foreach ($step in ($plan | Where-Object Run)) {
    try {
        & $step.Path
    } catch {
        Write-Host "  ✗ $($step.Name) FAILED: $_" -ForegroundColor Red
        $failed += $step.Name
    }
}

Write-Host ""
if ($failed.Count -eq 0) {
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║  ✅  Setup complete. Restart your terminal to enjoy.      ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
} else {
    Write-Host "⚠  Completed with failures: $($failed -join ', ')" -ForegroundColor Yellow
    exit 1
}
