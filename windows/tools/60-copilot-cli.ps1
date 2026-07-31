#Requires -Version 5.1
. "$PSScriptRoot\..\lib\common.ps1"
Write-Banner "GitHub Copilot CLI"

Refresh-Path
if (-not (Test-Command npm)) {
    Write-Warn2 "npm not found — run tools/20-node.ps1 first."
    exit 1
}

$listed = & npm ls -g --depth=0 2>$null | Out-String
if ($listed -match "@github/copilot@") {
    Write-Step "Updating @github/copilot via npm…"
    & npm update -g "@github/copilot" --silent 2>$null | Out-Null
    Write-Ok "Updated @github/copilot"
} else {
    Write-Step "Installing @github/copilot via npm…"
    & npm install -g "@github/copilot" --silent
    Write-Ok "Copilot CLI installed (command: copilot)"
}

Write-Warn2 "Run 'copilot' and follow the auth prompt on first launch."
