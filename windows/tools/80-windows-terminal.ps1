#Requires -Version 5.1
. "$PSScriptRoot\..\lib\common.ps1"
Write-Banner "Windows Terminal"

Install-WingetPackage -Id "Microsoft.WindowsTerminal" -DisplayName "Windows Terminal"

$src = Join-Path (Get-ScaffolderRoot) "configs\windows-terminal\settings.json"
# Standard WT settings location:
$dst = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

if (-not (Test-Path (Split-Path $dst -Parent))) {
    Write-Warn2 "Windows Terminal app folder not found yet. Launch Windows Terminal once, then re-run this script."
    return
}
Deploy-Config -Source $src -Target $dst
Write-Warn2 "Machine-specific profile GUIDs in settings.json may need a one-time manual fix-up."
