#Requires -Version 5.1
. "$PSScriptRoot\..\lib\common.ps1"
Write-Banner "Python 3"

Install-WingetPackage -Id "Python.Python.3.12" -DisplayName "Python 3.12"
Refresh-Path

$py = Get-WorkingPython
if ($py) {
    Write-Step "Installing user-level Python packages (pynvim, black, pytest)…"
    foreach ($pkg in @("pynvim", "black", "pytest")) {
        try { & $py -m pip install --user --upgrade $pkg --quiet; Write-Ok "pip --user $pkg" }
        catch { Write-Warn2 "pip install $pkg failed: $_" }
    }
} else {
    Write-Warn2 "python3 not on PATH yet (or shadowed by the Microsoft Store 'python' alias stub) — open a new shell and re-run tools/25-python.ps1"
}
