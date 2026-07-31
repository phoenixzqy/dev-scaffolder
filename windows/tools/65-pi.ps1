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
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install $package"
    }
    Write-Ok "Pi installed (command: pi)"
}

$plugins = @(
    "npm:pi-subagents"
    "npm:@codewithkenzo/pi-theme-switcher"
    "npm:@milanglacier/pi-plan-mode"
    "npm:pi-goal-list-loop-audit"
    "npm:@vigolium/piolium"
    "npm:pi-mcp-adapter"
    "npm:pi-web-access"
    "npm:pi-lens"
)

$installedPlugins = & pi list 2>$null | Out-String
if ($LASTEXITCODE -ne 0) {
    throw "Failed to list installed Pi plugins"
}

foreach ($plugin in $plugins) {
    $pluginName = $plugin -replace '^npm:', ''
    if ($installedPlugins -match [regex]::Escape($pluginName)) {
        Write-Skip "$pluginName already present"
    } else {
        Write-Step "Installing $plugin…"
        & pi install $plugin
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install $plugin"
        }
        Write-Ok "Installed $plugin"
    }
}

Write-Warn2 "Run 'pi', then use '/login' to authenticate."
