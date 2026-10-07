#Requires -Version 5.1
# Called by devbox.py on native Windows, or run directly in PowerShell.
[CmdletBinding()]
param([string]$PublicKey, [switch]$Apply)
$ErrorActionPreference = 'Stop'

if (-not $Apply) {
    Write-Output 'Preview: install OpenSSH Server, enable/start sshd, and allow LAN TCP 22.'
    if ($PublicKey) { Write-Output "Authorize public key: $PublicKey" }
    Write-Output 'Run with -Apply in an Administrator PowerShell to execute.'
    exit 0
}
$principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Open an Administrator PowerShell as the intended SSH login user, then rerun.'
}

# Validate before installing anything. No private keys or authorized_keys options.
$key = $null
if ($PublicKey) {
    $key = (Get-Content -LiteralPath $PublicKey -Raw).Trim()
    if ($key.Length -gt 16384 -or $key.Contains("`n") -or $key.Contains("`r") -or
        $key -notmatch '^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521)|sk-ssh-ed25519@openssh.com|sk-ecdsa-sha2-nistp256@openssh.com) [A-Za-z0-9+/]+={0,2}( .*)?$') {
        throw 'Supply one OpenSSH public key (.pub), not a private key or options.'
    }
}

$capability = Get-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0'
if ($capability.State -ne 'Installed') {
    $result = Add-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0'
    if ($result.RestartNeeded) { throw 'OpenSSH installation requires a Windows restart; restart and rerun.' }
}

if ($key) {
    # Stock Windows OpenSSH uses this shared file for Administrator logins.
    $target = Join-Path $env:ProgramData 'ssh\administrators_authorized_keys'
    $null = New-Item -ItemType Directory -Path (Split-Path $target) -Force
    if ((Test-Path -LiteralPath $target) -and
        ((Get-Item -LiteralPath $target).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw 'Refusing to modify a linked administrators_authorized_keys file.'
    }
    $existing = if (Test-Path -LiteralPath $target) { [IO.File]::ReadAllText($target) } else { '' }
    $keyIdentity = ($key -split '\s+')[0..1] -join ' '
    $found = @($existing -split '\r?\n' | Where-Object {
        $parts = $_ -split '\s+'
        $parts.Count -ge 2 -and (($parts[0..1] -join ' ') -eq $keyIdentity)
    }).Count -gt 0
    if (-not $found) {
        $separator = if ($existing -and -not $existing.EndsWith("`n")) { "`r`n" } else { '' }
        [IO.File]::WriteAllText($target, $existing + $separator + $key + "`r`n", [Text.UTF8Encoding]::new($false))
    }
    $acl = [Security.AccessControl.FileSecurity]::new()
    $acl.SetAccessRuleProtection($true, $false)
    $admins = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
    $system = [Security.Principal.SecurityIdentifier]::new('S-1-5-18')
    $acl.SetOwner($admins)
    foreach ($sid in @($admins, $system)) {
        $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid, 'FullControl', 'Allow'))
    }
    Set-Acl -LiteralPath $target -AclObject $acl
    Write-Output "Authorized key in $target (shared by Administrator accounts)."
}
Set-Service -Name sshd -StartupType Automatic
Start-Service sshd
if (-not (Get-NetFirewallRule -Name 'Devbox-SSH-LAN' -ErrorAction SilentlyContinue)) {
    $null = New-NetFirewallRule -Name 'Devbox-SSH-LAN' -DisplayName 'Devbox SSH (LAN)' `
        -Direction Inbound -Action Allow -Protocol TCP -LocalPort 22 -RemoteAddress LocalSubnet
}
Write-Output "SSH enabled. Login user: $env:USERNAME; port: 22. Existing firewall rules were preserved."
