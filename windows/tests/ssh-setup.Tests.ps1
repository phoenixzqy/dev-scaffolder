#Requires -Version 5.1
BeforeAll {
    $source = Join-Path $PSScriptRoot '../../tools/ssh-script/setup-windows.ps1'
    $tokens = $null
    $errors = $null
    $null = [Management.Automation.Language.Parser]::ParseFile($source, [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw ($errors | Out-String) }
    # Synthetic public-key blobs; no user credentials or private keys are involved.
    $laptopKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAABAgMEBQYHCAkKCwwNDg8QERITFBUWFxgZGhscHR4f laptop'
    $desktopKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB8eHRwbGhkYFxYVFBMSERAPDg0MCwoJCAcGBQQDAgEA desktop'
}
Describe 'SSH setup public-key discovery' {
    BeforeEach {
        $bundle = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $null = New-Item -ItemType Directory -Path $bundle
        $helper = Join-Path $bundle 'setup-windows.ps1'
        Copy-Item -LiteralPath $source -Destination $helper
        $keyDirectory = Join-Path $bundle 'pub-keys'
        Mock Get-WindowsCapability { throw 'Server installation must not run' }
    }
    It 'previews both client keys beside the helper from another working directory' {
        $null = New-Item -ItemType Directory -Path $keyDirectory
        Set-Content -LiteralPath (Join-Path $keyDirectory 'laptop.pub') -Value $laptopKey -Encoding ascii
        Set-Content -LiteralPath (Join-Path $keyDirectory 'desktop.pub') -Value $desktopKey -Encoding ascii
        Set-Content -LiteralPath (Join-Path $keyDirectory 'notes.txt') -Value 'not a key'
        $nested = Join-Path $keyDirectory 'nested'
        $null = New-Item -ItemType Directory -Path $nested
        Set-Content -LiteralPath (Join-Path $nested 'ignored.pub') -Value 'not a key'
        $output = @(& $helper)
        @($output | Where-Object { $_ -like 'Authorize public key:*' }).Count | Should -Be 2
        ($output -join "`n") | Should -Match 'desktop\.pub'
        ($output -join "`n") | Should -Match 'laptop\.pub'
        Should -Invoke Get-WindowsCapability -Times 0
    }
    It 'uses only the explicit public key even if the folder contains invalid keys' {
        $null = New-Item -ItemType Directory -Path $keyDirectory
        Set-Content -LiteralPath (Join-Path $keyDirectory 'bad.pub') -Value 'not a key'
        $selected = Join-Path $bundle 'selected.pub'
        Set-Content -LiteralPath $selected -Value $laptopKey -Encoding ascii
        $output = @(& $helper -PublicKey $selected)
        @($output | Where-Object { $_ -like 'Authorize public key:*' }).Count | Should -Be 1
        ($output -join "`n") | Should -Match 'selected\.pub'
        Should -Invoke Get-WindowsCapability -Times 0
    }
    It 'reports missing and empty public-key folders' {
        (@(& $helper) -join "`n") | Should -Match 'No public keys found'
        $null = New-Item -ItemType Directory -Path $keyDirectory
        (@(& $helper) -join "`n") | Should -Match 'No public keys found'
        Should -Invoke Get-WindowsCapability -Times 0
    }
    It 'rejects an invalid discovered key before starting server installation' {
        $null = New-Item -ItemType Directory -Path $keyDirectory
        Set-Content -LiteralPath (Join-Path $keyDirectory 'a-laptop.pub') -Value $laptopKey -Encoding ascii
        Set-Content -LiteralPath (Join-Path $keyDirectory 'z-invalid.pub') -Value 'private key'
        { & $helper -Apply } | Should -Throw '*Supply one OpenSSH public key*'
        Should -Invoke Get-WindowsCapability -Times 0
    }
}
