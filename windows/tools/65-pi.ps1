#Requires -Version 5.1
. "$PSScriptRoot\..\lib\common.ps1"
Write-Banner "Pi Coding Agent"

Refresh-Path
if (-not (Test-Command npm)) {
    Write-Warn2 "npm not found — run tools/20-node.ps1 first."
    exit 1
}

$package = "@earendil-works/pi-coding-agent"
$listed = & npm ls -g --depth=0 2>$null | Out-String
if ($listed -match [regex]::Escape("$package@")) {
    Write-Skip "Pi already present"
} else {
    Write-Step "Installing $package via npm…"
    & npm install -g --ignore-scripts $package --silent
    Write-Ok "Pi installed (command: pi)"
}

Write-Warn2 "Run 'pi', then use '/login' to authenticate."
