#Requires -Version 5.1
# Run on the Windows host in Administrator PowerShell for WSL2 NAT networking.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Distro,
    [Parameter(Mandatory = $true)][string]$ListenAddress,
    [ValidateRange(1, 65535)][int]$Port = 2222,
    [ValidateRange(1, 65535)][int]$WslPort = 22,
    [switch]$Apply,
    [switch]$Remove
)
$ErrorActionPreference = 'Stop'
function Invoke-Checked {
    param([string]$Executable, [string[]]$Arguments)
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Executable failed with exit code $LASTEXITCODE" }
}
function Update-Forwarding {
    param([bool]$Occupied, $Ours, [string]$ListenAddress, [int]$Port,
          [string]$WslAddress, [int]$WslPort, [string]$RuleName, [string]$Distro)
    $operation = if ($occupied) { 'set' } else { 'add' }
    Invoke-Checked netsh.exe @('interface', 'portproxy', $operation, 'v4tov4', "listenport=$Port", "listenaddress=$ListenAddress", "connectport=$WslPort", "connectaddress=$wslAddress")
    if (-not $ours) {
        try {
            $null = New-NetFirewallRule -Name $ruleName -DisplayName "Devbox WSL SSH ($Distro)" `
                -Direction Inbound -Action Allow -Protocol TCP -LocalAddress $ListenAddress `
                -LocalPort $Port -RemoteAddress LocalSubnet
        } catch {
            $firewallFailure = $_
            # This mapping was just created; leave existing mappings intact on refresh.
            try {
                Invoke-Checked netsh.exe @('interface', 'portproxy', 'delete', 'v4tov4', "listenport=$Port", "listenaddress=$ListenAddress")
            } catch {
                Write-Warning "Could not roll back forwarding: $_"
            }
            throw $firewallFailure
        }
    }
}
$ip = $null
if (-not [Net.IPAddress]::TryParse($ListenAddress, [ref]$ip) -or
    $ip.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork -or
    $ListenAddress -eq '0.0.0.0') {
    throw 'ListenAddress must be a specific Windows IPv4 address, for example 192.168.1.20.'
}
$ruleName = "Devbox-WSL-$ListenAddress-$Port"
if ($Apply) {
    $principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Run this helper in Administrator PowerShell.'
    }
}
if ($Remove) {
    Write-Output "Remove forwarding and its firewall rule at ${ListenAddress}:$Port"
    if ($Apply) {
        $rule = Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue
        if (-not $rule) { throw 'No helper-owned firewall rule found; refusing to remove an unowned mapping.' }
        Invoke-Checked netsh.exe @('interface', 'portproxy', 'delete', 'v4tov4', "listenport=$Port", "listenaddress=$ListenAddress")
        $rule | Remove-NetFirewallRule
    } else { Write-Output 'Preview only; add -Apply to execute.' }
    exit 0
}
# Starting the selected distribution also ensures its network exists.
$addressOutput = & wsl.exe -d $Distro -- sh -c "ip -4 route get 1.1.1.1"
if ($LASTEXITCODE -ne 0) { throw 'Could not query the selected WSL distribution.' }
if (($addressOutput -join ' ') -notmatch '\bsrc\s+([0-9.]+)') { throw 'Could not find the WSL source IPv4 address.' }
$wslAddress = $Matches[1]
Write-Output "Forward ${ListenAddress}:$Port -> ${wslAddress}:$WslPort ($Distro)"
if (-not $Apply) { Write-Output 'Preview only; add -Apply to execute.'; exit 0 }
if (-not (Get-NetIPAddress -AddressFamily IPv4 -IPAddress $ListenAddress -ErrorAction SilentlyContinue)) {
    throw 'ListenAddress is not assigned to this Windows host.'
}
Set-Service iphlpsvc -StartupType Automatic
Start-Service iphlpsvc
# Refuse to overwrite someone else's listener. A rerun may refresh our own mapping.
$existing = & netsh.exe interface portproxy show v4tov4
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect existing portproxy mappings.' }
$occupied = @($existing | Where-Object { $_ -match ('^\s*' + [regex]::Escape($ListenAddress) + '\s+' + $Port + '\s+') }).Count -gt 0
$ours = Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue
if ($occupied -and -not $ours) { throw 'A forwarding rule already owns this address and port; choose another port.' }
if (-not $occupied) {
    $listeners = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue
    if ($listeners | Where-Object { $_.LocalAddress -in @($ListenAddress, '0.0.0.0', '::') }) {
        throw 'A service already listens on this port; choose another port.'
    }
}
Update-Forwarding -Occupied $occupied -Ours $ours -ListenAddress $ListenAddress -Port $Port `
    -WslAddress $wslAddress -WslPort $WslPort -RuleName $ruleName -Distro $Distro
Write-Output 'Forwarding configured. Rerun after WSL restarts or its IP changes.'
