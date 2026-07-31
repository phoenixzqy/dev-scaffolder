# ============================================================================
# capture.ps1 — Re-snapshot live configs from the current machine into configs/
# Run this whenever you tweak a tool's settings and want the scaffolder to
# pick up the change. Commit the resulting diff.
# ============================================================================
#Requires -Version 5.1
[CmdletBinding()] param()

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\lib\common.ps1"
$root = Get-ScaffolderRoot

Write-Banner "Capturing live configs -> configs/"

function Snap {
    param([string]$Src, [string]$Dst)
    if (-not (Test-Path $Src)) { Write-Warn2 "missing: $Src"; return }
    Ensure-Dir (Split-Path $Dst -Parent)
    Copy-Item -LiteralPath $Src -Destination $Dst -Force -Recurse
    Write-Ok "$Src -> $(Resolve-Path -LiteralPath $Dst)"
}

Snap "$env:USERPROFILE\.config\starship.toml"                                           "$root\configs\starship\starship.toml"
Snap "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" "$root\configs\windows-terminal\settings.json"
Snap "$env:APPDATA\lazygit\config.yml"                                                  "$root\configs\lazygit\config.yml"
Snap "$env:APPDATA\GitHub CLI\config.yml"                                               "$root\configs\gh\config.yml"

# pwsh profile — use PROFILE variable to pick the right path on this machine
$psProfile = $PROFILE.CurrentUserCurrentHost
if ($psProfile -and (Test-Path $psProfile)) {
    Snap $psProfile "$root\configs\pwsh\Microsoft.PowerShell_profile.ps1"
}

# nvim
$nvim = "$env:LOCALAPPDATA\nvim"
if (Test-Path $nvim) {
    Remove-Item "$root\configs\nvim" -Recurse -Force -ErrorAction SilentlyContinue
    Ensure-Dir "$root\configs\nvim"
    Copy-Item "$nvim\init.lua"         "$root\configs\nvim\init.lua" -Force -ErrorAction SilentlyContinue
    if (Test-Path "$nvim\lua") {
        Copy-Item "$nvim\lua" "$root\configs\nvim\lua" -Recurse -Force
    }
    Write-Ok "nvim config snapshotted"
}

Write-Host ""
Write-Ok "Done. Review 'git diff' in $root and commit."
