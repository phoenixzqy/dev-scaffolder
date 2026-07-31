#Requires -Version 5.1
. "$PSScriptRoot\..\lib\common.ps1"
Write-Banner "JetBrainsMono Nerd Font"

$userFontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
Ensure-Dir $userFontDir

$already = Get-ChildItem $userFontDir -Filter "JetBrainsMono*NerdFont*.ttf" -ErrorAction SilentlyContinue
if ($already) {
    Write-Skip "JetBrainsMono Nerd Font"
    return
}

$fontUrl = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
$fontZip = "$env:TEMP\JetBrainsMono.zip"
$fontDir = "$env:TEMP\JetBrainsMono"

try {
    Write-Step "Downloading $fontUrl …"
    Invoke-WebRequest -Uri $fontUrl -OutFile $fontZip -UseBasicParsing
    if (Test-Path $fontDir) { Remove-Item $fontDir -Recurse -Force }
    Expand-Archive -Path $fontZip -DestinationPath $fontDir -Force

    $regPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
    if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }

    Get-ChildItem "$fontDir\*.ttf" | ForEach-Object {
        $dest = Join-Path $userFontDir $_.Name
        Copy-Item $_.FullName $dest -Force
        $fontName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name) + " (TrueType)"
        New-ItemProperty -Path $regPath -Name $fontName -Value $dest -PropertyType String -Force | Out-Null
    }
    Remove-Item $fontZip, $fontDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Ok "Installed JetBrainsMono Nerd Font (per-user)."
} catch {
    Write-Warn2 "Font install failed: $_"
    Write-Warn2 "Manual download: https://www.nerdfonts.com/font-downloads"
}
