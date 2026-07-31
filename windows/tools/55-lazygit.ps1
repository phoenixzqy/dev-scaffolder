#Requires -Version 5.1
. "$PSScriptRoot\..\lib\common.ps1"
Write-Banner "Lazygit"

Install-ScoopPackage -Name "lazygit" -Bucket "extras"

$src = Join-Path (Get-ScaffolderRoot) "configs\lazygit\config.yml"
$dst = Join-Path $env:APPDATA        "lazygit\config.yml"
Deploy-Config -Source $src -Target $dst
