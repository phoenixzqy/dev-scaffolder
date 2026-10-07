#Requires -Version 5.1
BeforeAll {
    $helper = Join-Path $PSScriptRoot '../../tools/ssh-script/wsl-forward.ps1'
    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($helper, [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw ($errors | Out-String) }
    # Load only the functions so tests never start WSL or change host networking.
    $ast.FindAll({ param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst]
    }, $false) | ForEach-Object { Invoke-Expression $_.Extent.Text }
    $parameters = @{
        Occupied = $false; Ours = $null; ListenAddress = '192.168.1.20'; Port = 2222
        WslAddress = '172.20.1.2'; WslPort = 22; RuleName = 'test-rule'; Distro = 'Ubuntu'
    }
}
Describe 'WSL forwarding failure recovery' {
    BeforeEach {
        Mock Invoke-Checked {}
        Mock New-NetFirewallRule { throw 'firewall creation failed' }
    }
    It 'rolls back a new mapping and preserves the firewall failure' {
        { Update-Forwarding @parameters } | Should -Throw '*firewall creation failed*'
        Should -Invoke Invoke-Checked -Times 1 -Exactly -ParameterFilter { $Arguments[2] -eq 'add' }
        Should -Invoke Invoke-Checked -Times 1 -Exactly -ParameterFilter { $Arguments[2] -eq 'delete' }
    }
    It 'retains the original error if rollback also fails' {
        Mock Invoke-Checked { throw 'rollback failed' } -ParameterFilter { $Arguments[2] -eq 'delete' }
        Mock Write-Warning {}
        { Update-Forwarding @parameters } | Should -Throw '*firewall creation failed*'
        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like '*rollback failed*' }
    }
    It 'refreshes an existing owned mapping without deleting it' {
        $refresh = $parameters.Clone()
        $refresh.Occupied = $true
        $refresh.Ours = [pscustomobject]@{ Name = 'test-rule' }
        Update-Forwarding @refresh
        Should -Invoke Invoke-Checked -Times 1 -Exactly -ParameterFilter { $Arguments[2] -eq 'set' }
        Should -Invoke Invoke-Checked -Times 0 -ParameterFilter { $Arguments[2] -eq 'delete' }
        Should -Invoke New-NetFirewallRule -Times 0
    }
}
