# Ensure winget is present; bootstrap scoop + extras bucket.
#Requires -Version 5.1
. "$PSScriptRoot\..\lib\common.ps1"

Write-Banner "Package Managers"

if (-not (Test-Command winget)) {
    Write-Host "ERROR: winget not found. Install 'App Installer' from the Microsoft Store." -ForegroundColor Red
    exit 1
}
Write-Ok "winget available"

Ensure-Scoop
Ensure-ScoopBucket -Name extras
Write-Ok "scoop + extras bucket ready"
