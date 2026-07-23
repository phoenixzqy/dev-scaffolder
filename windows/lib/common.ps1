# Shared helpers for the scaffolder. Dot-source from every tools/*.ps1 script.
#Requires -Version 5.1

$ErrorActionPreference = "Stop"

# Resolve repo root regardless of where we were invoked from.
if (-not $script:ScaffolderRoot) {
    $script:ScaffolderRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Get-ScaffolderRoot { $script:ScaffolderRoot }

function Write-Step    { param([string]$m) Write-Host "▸ $m" -ForegroundColor Cyan }
function Write-Ok      { param([string]$m) Write-Host "  ✓ $m" -ForegroundColor Green }
function Write-Warn2   { param([string]$m) Write-Host "  ⚠ $m" -ForegroundColor Yellow }
function Write-Skip    { param([string]$m) Write-Host "  • $m (already present)" -ForegroundColor DarkGray }

function Write-Banner {
    param([string]$Title)
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host ("║  {0,-56}║" -f $Title) -ForegroundColor Magenta
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
}

function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function Test-Command {
    param([Parameter(Mandatory)][string]$Name)
    [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-WorkingPython {
    # Windows ships "python"/"python3" App Execution Alias stubs in
    # %LOCALAPPDATA%\Microsoft\WindowsApps that satisfy Test-Command / Get-Command
    # but exit 9009 with a "Python was not found; run without arguments to
    # install from the Microsoft Store" message when no real interpreter is on
    # PATH ahead of them. Actually invoke each candidate so we only return a
    # command name that truly runs.
    foreach ($name in @("python3", "python")) {
        if (-not (Test-Command $name)) { continue }
        try {
            & $name --version *> $null
            if ($LASTEXITCODE -eq 0) { return $name }
        } catch { }
    }
    return $null
}

function Ensure-Dir {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
}

function Backup-Path {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    $stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup = "$Path.bak.$stamp"
    Move-Item -LiteralPath $Path -Destination $backup -Force
    Write-Warn2 "Backed up existing $Path -> $backup"
    return $backup
}

# Deploy a source file/dir from configs/ to a target location.
# Backs up any existing target first.
function Deploy-Config {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Target
    )
    if (-not (Test-Path $Source)) {
        throw "Source config not found: $Source"
    }
    Ensure-Dir (Split-Path $Target -Parent)
    if (Test-Path $Target) { Backup-Path $Target | Out-Null }

    if ((Get-Item $Source).PSIsContainer) {
        Copy-Item -Path $Source -Destination $Target -Recurse -Force
    } else {
        Copy-Item -Path $Source -Destination $Target -Force
    }
    Write-Ok "Deployed $Target"
}

# Install a winget package id, idempotent.
function Install-WingetPackage {
    param(
        [Parameter(Mandatory)][string]$Id,
        [string]$DisplayName = $null
    )
    if (-not (Test-Command winget)) {
        throw "winget is required. Install 'App Installer' from the Microsoft Store."
    }
    $name = if ($DisplayName) { $DisplayName } else { $Id }
    $listed = & winget list --id $Id --exact --source winget 2>$null | Out-String
    if ($listed -match [regex]::Escape($Id)) {
        Write-Step "Updating $name via winget…"
        & winget upgrade --id $Id --exact `
            --accept-package-agreements --accept-source-agreements `
            --silent --disable-interactivity 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Ok "$name is up to date"
        } else {
            Write-Ok "Updated $name"
        }
    } else {
        Write-Step "Installing $name via winget…"
        & winget install --id $Id --exact `
            --accept-package-agreements --accept-source-agreements `
            --silent --disable-interactivity | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warn2 "winget exit=$LASTEXITCODE for $Id (may already be installed)"
        } else {
            Write-Ok "Installed $name"
        }
    }
    Refresh-Path
}

function Ensure-Scoop {
    if (Test-Command scoop) { return }
    Write-Step "Bootstrapping scoop…"
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
    Refresh-Path
    if (-not (Test-Command scoop)) { throw "Scoop bootstrap failed." }
    Write-Ok "scoop installed"
}

function Ensure-ScoopBucket {
    param([Parameter(Mandatory)][string]$Name)
    Ensure-Scoop
    $buckets = & scoop bucket list 2>$null | Out-String
    if ($buckets -notmatch "(?m)^\s*$Name\b") {
        Write-Step "Adding scoop bucket '$Name'…"
        & scoop bucket add $Name | Out-Null
    }
}

function Install-ScoopPackage {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Bucket = $null
    )
    Ensure-Scoop
    if ($Bucket) { Ensure-ScoopBucket -Name $Bucket }
    $spec = if ($Bucket) { "$Bucket/$Name" } else { $Name }
    $installed = & scoop list 2>$null | Out-String
    if ($installed -match "(?m)^\s*$([regex]::Escape($Name))\s") {
        Write-Step "Updating $Name via scoop…"
        & scoop update $Name 2>$null | Out-Null
        Write-Ok "Updated $Name"
    } else {
        Write-Step "Installing $spec via scoop…"
        & scoop install $spec
        Write-Ok "Installed $Name"
    }
    Refresh-Path
}
