#Requires -Version 5.1
. "$PSScriptRoot\..\lib\common.ps1"
Write-Banner "Starship Prompt"

# Standalone runs need the font too; the orchestrator owns dependency selection.
if ($env:DEV_SCAFFOLDER_FONTS_HANDLED -ne "1") {
    & "$PSScriptRoot\40-fonts.ps1"
}

Install-WingetPackage -Id "Starship.Starship" -DisplayName "Starship"

$src = Join-Path (Get-ScaffolderRoot) "configs\starship\starship.toml"
$dst = Join-Path $env:USERPROFILE ".config\starship.toml"
Deploy-Config -Source $src -Target $dst

Write-Warn2 "Ensure your PowerShell profile contains: Invoke-Expression (&starship init powershell)"
Write-Warn2 "(The tools/90-pwsh-profile.ps1 script handles this automatically.)"

Write-Warn2 "Select JetBrainsMono Nerd Font in your terminal settings and restart the terminal. For SSH, install and select it on the terminal client."
