#Requires -Version 5.1
. "$PSScriptRoot\..\lib\common.ps1"
Write-Banner "Neovim + plugins"

Install-WingetPackage -Id "Neovim.Neovim" -DisplayName "Neovim"
Refresh-Path

# Deploy config
$srcDir  = Join-Path (Get-ScaffolderRoot) "configs\nvim"
$nvimDir = Join-Path $env:LOCALAPPDATA     "nvim"

Write-Step "Deploying Neovim config to $nvimDir …"
if (Test-Path $nvimDir) { Backup-Path $nvimDir | Out-Null }
Copy-Item -Path $srcDir -Destination $nvimDir -Recurse -Force
Write-Ok "Config deployed"

# Plugin bootstrap via lazy.nvim (headless)
if (Test-Command nvim) {
    Write-Step "Syncing plugins (lazy.nvim headless)…"
    try {
        & nvim --headless "+Lazy! sync" "+qa" 2>$null
        Write-Ok "Plugins synced"
    } catch {
        Write-Warn2 "Plugin sync may need a manual 'nvim' launch to finish."
    }
} else {
    Write-Warn2 "nvim not on PATH yet; open a new shell and run ':Lazy sync' inside nvim."
}
