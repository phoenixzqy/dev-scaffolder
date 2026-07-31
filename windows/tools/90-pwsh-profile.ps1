#Requires -Version 5.1
. "$PSScriptRoot\..\lib\common.ps1"
Write-Banner "PowerShell Profile"

$src = Join-Path (Get-ScaffolderRoot) "configs\pwsh\Microsoft.PowerShell_profile.ps1"

# Use the *current host's* resolved profile path — this handles both OneDrive-
# redirected Documents and the local-only Documents cases.
$dst = $PROFILE.CurrentUserCurrentHost
if (-not $dst) {
    $dst = Join-Path $env:USERPROFILE "Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
}

Deploy-Config -Source $src -Target $dst

Write-Warn2 "Restart PowerShell (or run '. \$PROFILE') to activate the profile."
