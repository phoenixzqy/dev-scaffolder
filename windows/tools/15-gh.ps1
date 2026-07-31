#Requires -Version 5.1
. "$PSScriptRoot\..\lib\common.ps1"
Write-Banner "GitHub CLI"

Install-WingetPackage -Id "GitHub.cli" -DisplayName "GitHub CLI (gh)"

$src = Join-Path (Get-ScaffolderRoot) "configs\gh\config.yml"
$dst = Join-Path $env:APPDATA  "GitHub CLI\config.yml"
if (Test-Path $src) { Deploy-Config -Source $src -Target $dst }

Write-Warn2 "Run 'gh auth login' once to authenticate (oauth tokens are never committed to the repo)."
