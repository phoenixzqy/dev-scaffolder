# Pester 5 tests for install-all.ps1 (orchestrator) and repo layout invariants.
#Requires -Version 5.1
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

BeforeAll {
    $script:RepoRoot  = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    $script:Installer = Join-Path $script:RepoRoot "install-all.ps1"
    $script:ToolsDir  = Join-Path $script:RepoRoot "tools"
}

# Pre-compute file lists at DISCOVERY time (BeforeAll hasn't run yet here).
$DiscoveryRoot  = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$DiscoveryTools = Join-Path $DiscoveryRoot "tools"
$AllScriptsCases = Get-ChildItem $DiscoveryRoot -Recurse -Filter *.ps1 -File |
    Where-Object { $_.FullName -notmatch '\\configs\\' } |
    ForEach-Object { @{ name = $_.FullName.Substring($DiscoveryRoot.Length + 1); path = $_.FullName } }
$ToolScriptCases = Get-ChildItem $DiscoveryTools -Filter "*.ps1" |
    ForEach-Object { @{ name = $_.Name; path = $_.FullName } }
# Includes configs/ — a mangled deployed profile breaks the user's shell too.
$EveryScriptCases = Get-ChildItem $DiscoveryRoot -Recurse -Filter *.ps1 -File |
    ForEach-Object { @{ name = $_.FullName.Substring($DiscoveryRoot.Length + 1); path = $_.FullName } }

Describe "Repo layout" {
    It "has the orchestrator" { Test-Path $script:Installer | Should -BeTrue }
    It "has capture.ps1"      { Test-Path (Join-Path $script:RepoRoot "capture.ps1") | Should -BeTrue }
    It "has lib/common.ps1"   { Test-Path (Join-Path $script:RepoRoot "lib\common.ps1") | Should -BeTrue }

    It "has at least one tool script with NN- prefix" {
        $scripts = Get-ChildItem $script:ToolsDir -Filter "*.ps1"
        $scripts.Count | Should -BeGreaterThan 0
        foreach ($s in $scripts) { $s.Name | Should -Match '^\d{2}-' }
    }
}

Describe "All .ps1 files parse without syntax errors" {
    It "<name>" -ForEach $AllScriptsCases {
        $errs = $null
        $null = [System.Management.Automation.PSParser]::Tokenize(
            (Get-Content -LiteralPath $path -Raw), [ref]$errs)
        if ($errs -and $errs.Count) {
            $errs | ForEach-Object { Write-Host "  $_" }
        }
        ($errs.Count) | Should -Be 0
    }
}

# Windows PowerShell 5.1 decodes BOM-less files as ANSI (cp1252), which mangles
# every non-ASCII glyph. An em dash (U+2014 = E2 80 94) becomes 'â€”' — and that
# trailing U+201D is a smart quote that 5.1 honours as a string delimiter, so the
# literal terminates early and the file stops parsing. A BOM prevents all of it.
Describe "Every .ps1 is UTF-8 with a BOM (Windows PowerShell 5.1 safety)" {
    It "<name>" -ForEach $EveryScriptCases {
        $bytes = [System.IO.File]::ReadAllBytes($path)
        $bytes.Length | Should -BeGreaterThan 2
        @($bytes[0], $bytes[1], $bytes[2]) -join ',' | Should -Be '239,187,191'
    }
}

Describe "Every tools/*.ps1 dot-sources lib/common.ps1" {
    It "<name>" -ForEach $ToolScriptCases {
        $content = Get-Content -LiteralPath $path -Raw
        $content | Should -Match '\.\s+"\$PSScriptRoot\\\.\.\\lib\\common\.ps1"'
    }
}

Describe "Orchestrator -DryRun" {
    BeforeAll {
        $script:DryRunAll  = & pwsh -NoProfile -File $script:Installer -DryRun *>&1 | Out-String
        $script:DryRunOnly = & pwsh -NoProfile -File $script:Installer -DryRun -Only nvim,starship *>&1 | Out-String
        $script:DryRunSkip = & pwsh -NoProfile -File $script:Installer -DryRun -Skip windows-terminal,pwsh-profile *>&1 | Out-String
    }

    It "prints every tool name" {
        foreach ($n in "package-managers","git","gh","node","python","cli-tools","fonts","starship","lazygit","copilot-cli","pi","nvim","windows-terminal","pwsh-profile") {
            $script:DryRunAll | Should -Match ([regex]::Escape($n))
        }
    }

    It "does not execute any tool script" {
        $script:DryRunAll | Should -Not -Match 'Installing .* via winget'
        $script:DryRunAll | Should -Match 'dry run'
    }

    It "-Only narrows the plan" {
        $script:DryRunOnly | Should -Match '\[\+\] starship'
        $script:DryRunOnly | Should -Match '\[\+\] nvim'
        $script:DryRunOnly | Should -Match '\[ \] git'
        $script:DryRunOnly | Should -Match '\[ \] fonts'
    }

    It "-Skip removes entries" {
        $script:DryRunSkip | Should -Match '\[ \] windows-terminal'
        $script:DryRunSkip | Should -Match '\[ \] pwsh-profile'
        $script:DryRunSkip | Should -Match '\[\+\] nvim'
    }
}

Describe "Captured configs exist" {
    It "<path>" -ForEach @(
        @{ path = "configs\starship\starship.toml" }
        @{ path = "configs\windows-terminal\settings.json" }
        @{ path = "configs\lazygit\config.yml" }
        @{ path = "configs\gh\config.yml" }
        @{ path = "configs\pwsh\Microsoft.PowerShell_profile.ps1" }
        @{ path = "configs\nvim\init.lua" }
        @{ path = "configs\nvim\lua\settings.lua" }
        @{ path = "configs\nvim\lua\keymaps.lua" }
        @{ path = "configs\nvim\lua\plugins.lua" }
    ) {
        Test-Path (Join-Path $script:RepoRoot $path) | Should -BeTrue
    }

    It "configs/gh/config.yml has no hosts/oauth tokens" {
        $c = Get-Content -LiteralPath (Join-Path $script:RepoRoot "configs\gh\config.yml") -Raw
        $c | Should -Not -Match '(?i)oauth_token'
        $c | Should -Not -Match '(?i)ghp_|gho_|ghs_'
    }
}
