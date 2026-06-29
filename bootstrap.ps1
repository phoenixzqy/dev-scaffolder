<#
.SYNOPSIS
  dev-scaffolder — one-line bootstrap (Windows / PowerShell).

.DESCRIPTION
  Run directly:
    irm https://raw.githubusercontent.com/phoenixzqy/dev-scaffolder/main/bootstrap.ps1 | iex

  To pass arguments to the installer (e.g. -Only jump), download then run:
    irm https://raw.githubusercontent.com/phoenixzqy/dev-scaffolder/main/bootstrap.ps1 -OutFile bootstrap.ps1
    .\bootstrap.ps1 -Only jump

  Overridable via environment variables:
    DEV_SCAFFOLDER_REPO   owner/name or full git URL  (default: phoenixzqy/dev-scaffolder)
    DEV_SCAFFOLDER_REF    branch / tag / commit        (default: main)
    DEV_SCAFFOLDER_DEST   clone destination            (default: ~\workspace\dev-scaffolder)
#>
[CmdletBinding()]
param([Parameter(ValueFromRemainingArguments = $true)] $InstallerArgs)

$ErrorActionPreference = 'Stop'

$Repo = if ($env:DEV_SCAFFOLDER_REPO) { $env:DEV_SCAFFOLDER_REPO } else { 'phoenixzqy/dev-scaffolder' }
$Ref  = if ($env:DEV_SCAFFOLDER_REF)  { $env:DEV_SCAFFOLDER_REF }  else { 'main' }
$Dest = if ($env:DEV_SCAFFOLDER_DEST) { $env:DEV_SCAFFOLDER_DEST } else { Join-Path $env:USERPROFILE 'workspace\dev-scaffolder' }

function Say  { param([string]$m) Write-Host "▸ $m" -ForegroundColor Cyan }
function Ok   { param([string]$m) Write-Host "  ✓ $m" -ForegroundColor Green }
function Die  { param([string]$m) Write-Host "✗ $m" -ForegroundColor Red; exit 1 }

Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║   dev-scaffolder bootstrap                               ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Magenta

# ── Ensure git ──────────────────────────────────────────────────────────────
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Say "git not found — installing via winget…"
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
        $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                    [System.Environment]::GetEnvironmentVariable('Path', 'User')
    } else {
        Die "winget not available. Install Git for Windows (https://git-scm.com) and re-run."
    }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Die "git still not found on PATH. Open a new terminal and re-run."
    }
    Ok "git installed"
}

# ── Resolve repo URL ────────────────────────────────────────────────────────
if ($Repo -match '://' -or $Repo -match '^git@') {
    $RepoUrl = $Repo
} else {
    $RepoUrl = "https://github.com/$Repo.git"
}

# ── Clone or update to the latest ───────────────────────────────────────────
if (Test-Path (Join-Path $Dest '.git')) {
    Say "Updating existing checkout at $Dest…"
    git -C $Dest remote set-url origin $RepoUrl
    git -C $Dest fetch --quiet origin $Ref
    git -C $Dest checkout --quiet $Ref
    git -C $Dest pull --ff-only --quiet origin $Ref 2>$null
    Ok "Updated to latest '$Ref'"
} else {
    Say "Cloning $RepoUrl ($Ref) → $Dest…"
    New-Item -ItemType Directory -Force -Path (Split-Path $Dest) | Out-Null
    git clone --branch $Ref --depth 1 $RepoUrl $Dest
    Ok "Cloned to $Dest"
}

# ── Run the Windows installer (passing through any args) ─────────────────────
$installer = Join-Path $Dest 'windows\install-all.ps1'
if (-not (Test-Path $installer)) { Die "Installer not found: $installer" }

Say "Running Windows installer…"
Set-Location (Join-Path $Dest 'windows')
& $installer @InstallerArgs
