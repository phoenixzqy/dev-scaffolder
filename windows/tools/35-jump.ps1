#Requires -Version 5.1
. "$PSScriptRoot\..\lib\common.ps1"
Write-Banner "j (jump) — directory jumper"

# Shared, cross-platform tools live at the repo root in /tools.
$repoRoot = (Resolve-Path (Join-Path (Get-ScaffolderRoot) "..")).Path
$src = Join-Path $repoRoot "tools\jump\jump.py"
$jumpHome = Join-Path $env:LOCALAPPDATA "dev-scaffolder\jump"
$marker = '# >>> dev-scaffolder jump (j) >>>'

if (-not (Test-Path $src)) {
    Write-Warn2 "jump.py not found at $src — skipping."
    exit 1
}

if (-not (Test-Command python)) {
    Write-Warn2 "python not found — run tools/25-python.ps1 first."
    exit 1
}

# 1. Install the engine — version-aware so re-running upgrades in place.
function Read-JumpVersion([string]$file) {
    if (-not (Test-Path $file)) { return $null }
    $line = Select-String -Path $file -Pattern '^__version__\s*=\s*["'']([^"'']+)["'']' |
        Select-Object -First 1
    if ($line) { return $line.Matches[0].Groups[1].Value }
    return $null
}

Ensure-Dir $jumpHome
$destPy = Join-Path $jumpHome "jump.py"
$srcVer = Read-JumpVersion $src
$destVer = Read-JumpVersion $destPy
if ($destVer -and $destVer -eq $srcVer) {
    Write-Skip "j already at v$destVer"
} else {
    if ($destVer) {
        Write-Step "Upgrading j v$destVer -> v$srcVer…"
    } else {
        Write-Step "Installing j v$srcVer to $jumpHome…"
    }
    Copy-Item $src $destPy -Force
    Write-Ok "j engine at v$srcVer (DB lives in $jumpHome)"
}

# 2. Write the shell integration — the `j` function lives here, so the tool is
#    self-contained and does not depend on the pwsh-profile config being deployed.
$initPs1 = @'
# dev-scaffolder jump (j) — shell integration (dot-sourced from your profile).
# `cd` must run in this shell, so `j` is a function: bare `j` opens a picker
# and we Set-Location into whatever path it prints; anything else is forwarded.
$env:JUMP_HOME = Join-Path $env:LOCALAPPDATA 'dev-scaffolder\jump'
function j {
  $jumpScript = Join-Path $env:JUMP_HOME 'jump.py'
  if ($args.Count -eq 0) {
    $target = & python $jumpScript select
    if ($LASTEXITCODE -eq 0 -and $target) { Set-Location $target }
  } else {
    & python $jumpScript @args
  }
}
'@
Set-Content -Path (Join-Path $jumpHome 'init.ps1') -Value $initPs1 -Encoding UTF8
Write-Ok "Shell integration written to $jumpHome\init.ps1"

# 3. Ensure the user's profile dot-sources it — idempotent, marker-guarded.
$profilePath = $PROFILE.CurrentUserCurrentHost
if (-not $profilePath) {
    $profilePath = Join-Path $env:USERPROFILE "Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
}
Ensure-Dir (Split-Path $profilePath)
if (-not (Test-Path $profilePath)) { New-Item -ItemType File -Path $profilePath -Force | Out-Null }

if (Select-String -Path $profilePath -SimpleMatch $marker -Quiet) {
    Write-Skip "j shell integration in $profilePath"
} else {
    $block = @"

$marker
`$__jumpInit = Join-Path `$env:LOCALAPPDATA 'dev-scaffolder\jump\init.ps1'
if (Test-Path `$__jumpInit) { . `$__jumpInit }
# <<< dev-scaffolder jump (j) <<<
"@
    Add-Content -Path $profilePath -Value $block
    Write-Ok "Wired j into $profilePath"
}

Write-Warn2 "Restart PowerShell (or '. \$PROFILE') to start using 'j'."
Write-Warn2 "Then: 'j add' to save a dir, 'j' to jump, 'j -h' for help."
