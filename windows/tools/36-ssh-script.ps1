#Requires -Version 5.1
. "$PSScriptRoot\..\lib\common.ps1"
Write-Banner "Devbox SSH"

$repoRoot = (Resolve-Path (Join-Path (Get-ScaffolderRoot) '..')).Path
$sshSource = Join-Path $repoRoot 'tools\ssh-script'
$sshDestination = if ($env:DEVBOX_SSH_HOME) { $env:DEVBOX_SSH_HOME } else {
    Join-Path $env:LOCALAPPDATA 'dev-scaffolder\ssh-script'
}
$files = @('README.md', 'setup-windows.ps1', 'wsl-forward.ps1', 'devbox.py')
$python = Get-WorkingPython
if (-not $python) { throw 'Python not found; run tools/25-python.ps1 first.' }
foreach ($file in $files) {
    if (-not (Test-Path -LiteralPath (Join-Path $sshSource $file))) { throw "Missing bundled file: $file" }
}
function Read-SshVersion([string]$file) {
    if (-not (Test-Path -LiteralPath $file)) { return $null }
    $line = Select-String -LiteralPath $file -Pattern '^__version__ = "([^"]*)"' | Select-Object -First 1
    if ($line) { return $line.Matches[0].Groups[1].Value }
    return $null
}
$version = Read-SshVersion (Join-Path $sshSource 'devbox.py')
if (-not $version) { throw 'Bundled version is missing.' }
$installed = Read-SshVersion (Join-Path $sshDestination 'devbox.py')
$complete = $true
foreach ($file in $files) {
    if (-not (Test-Path -LiteralPath (Join-Path $sshDestination $file))) { $complete = $false }
}
if ($installed -eq $version -and $complete) {
    Write-Skip "Devbox SSH already at v$version"
} else {
    foreach ($file in $files) {
        Deploy-Config -Source (Join-Path $sshSource $file) -Target (Join-Path $sshDestination $file)
    }
    Write-Ok "Devbox SSH installed at v$version"
}
Write-Step "Run: $python `"$(Join-Path $sshDestination 'devbox.py')`" --help"
Write-Step "SSH server setup remains an explicit 'setup --apply' command."
