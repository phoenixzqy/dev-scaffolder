#Requires -Version 5.1
. "$PSScriptRoot\..\lib\common.ps1"
Write-Banner "Node.js (nvm + LTS)"

# ── Install nvm-windows via winget ─────────────────────────────────────────
Install-WingetPackage -Id "CoreyButler.NVMforWindows" -DisplayName "nvm-windows"
Refresh-Path

if (-not (Test-Command nvm)) {
    Write-Warn2 "nvm not on PATH yet; open a new shell and re-run tools/20-node.ps1"
    exit 1
}

# ── Install Node.js LTS via nvm ───────────────────────────────────────────
Write-Step "Installing Node.js LTS via nvm…"
& nvm install lts 2>&1 | Out-Null
# nvm-windows requires a concrete version for 'use'; resolve from 'nvm list'
$installed = & nvm list 2>&1 | Out-String
$ltsVersion = [regex]::Match($installed, '(\d+\.\d+\.\d+)').Groups[1].Value
if ($ltsVersion) {
    & nvm use $ltsVersion 2>&1 | Out-Null
    Write-Ok "Node.js $ltsVersion active (nvm)"
} else {
    Write-Warn2 "Could not resolve installed LTS version from nvm list"
}
Refresh-Path

if (Test-Command npm) {
    Write-Step "Installing global npm packages (neovim provider, pnpm)…"
    foreach ($pkg in @("neovim", "pnpm")) {
        try { & npm install -g $pkg --silent | Out-Null; Write-Ok "npm -g $pkg" }
        catch { Write-Warn2 "npm install -g $pkg failed: $_" }
    }
} else {
    Write-Warn2 "npm not on PATH yet; open a new shell and re-run tools/20-node.ps1"
}
