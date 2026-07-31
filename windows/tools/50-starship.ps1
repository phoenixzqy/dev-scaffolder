#Requires -Version 5.1
. "$PSScriptRoot\..\lib\common.ps1"
Write-Banner "Starship Prompt"

Install-WingetPackage -Id "Starship.Starship" -DisplayName "Starship"

$src = Join-Path (Get-ScaffolderRoot) "configs\starship\starship.toml"
$dst = Join-Path $env:USERPROFILE ".config\starship.toml"
Deploy-Config -Source $src -Target $dst

Write-Warn2 "Ensure your PowerShell profile contains: Invoke-Expression (&starship init powershell)"
Write-Warn2 "(The tools/90-pwsh-profile.ps1 script handles this automatically.)"
