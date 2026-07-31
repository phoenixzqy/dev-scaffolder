# Pester 5 tests for lib/common.ps1 helpers. Safe — everything runs in $TestDrive.
#Requires -Version 5.1
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    . (Join-Path $script:RepoRoot "lib\common.ps1")
}

Describe "Ensure-Dir" {
    It "creates a missing directory" {
        $p = Join-Path $TestDrive "a\b\c"
        Test-Path $p | Should -BeFalse
        Ensure-Dir $p
        Test-Path $p | Should -BeTrue
    }

    It "is a no-op if the directory exists" {
        $p = Join-Path $TestDrive "existing"
        New-Item -ItemType Directory -Path $p | Out-Null
        { Ensure-Dir $p } | Should -Not -Throw
    }
}

Describe "Backup-Path" {
    It "returns null when target does not exist" {
        Backup-Path (Join-Path $TestDrive "nope") | Should -Be $null
    }

    It "renames an existing file to <name>.bak.<stamp>" {
        $p = Join-Path $TestDrive "foo.txt"
        Set-Content -LiteralPath $p -Value "hello"
        $backup = Backup-Path $p
        Test-Path $p      | Should -BeFalse
        Test-Path $backup | Should -BeTrue
        $backup           | Should -Match 'foo\.txt\.bak\.\d{8}-\d{6}$'
        Get-Content -LiteralPath $backup | Should -Be "hello"
    }
}

Describe "Deploy-Config" {
    It "copies the source to the target when no target exists" {
        $src = Join-Path $TestDrive "src.toml"
        $dst = Join-Path $TestDrive "out\sub\dst.toml"
        Set-Content -LiteralPath $src -Value "x = 1"
        Deploy-Config -Source $src -Target $dst
        Test-Path $dst | Should -BeTrue
        Get-Content -LiteralPath $dst | Should -Be "x = 1"
    }

    It "backs up an existing target before overwriting" {
        $src = Join-Path $TestDrive "src2.toml"
        $dst = Join-Path $TestDrive "out2\dst2.toml"
        Set-Content -LiteralPath $src -Value "NEW"
        New-Item -ItemType Directory -Path (Split-Path $dst -Parent) | Out-Null
        Set-Content -LiteralPath $dst -Value "OLD"

        Deploy-Config -Source $src -Target $dst
        Get-Content -LiteralPath $dst | Should -Be "NEW"

        $backups = Get-ChildItem (Split-Path $dst -Parent) -Filter "dst2.toml.bak.*"
        $backups.Count                        | Should -Be 1
        Get-Content -LiteralPath $backups[0].FullName | Should -Be "OLD"
    }

    It "copies a directory recursively" {
        $srcDir = Join-Path $TestDrive "srcdir"
        New-Item -ItemType Directory -Path "$srcDir\sub" | Out-Null
        Set-Content -LiteralPath "$srcDir\a.txt"     -Value "A"
        Set-Content -LiteralPath "$srcDir\sub\b.txt" -Value "B"

        $dstDir = Join-Path $TestDrive "dstdir"
        Deploy-Config -Source $srcDir -Target $dstDir

        Get-Content -LiteralPath "$dstDir\a.txt"     | Should -Be "A"
        Get-Content -LiteralPath "$dstDir\sub\b.txt" | Should -Be "B"
    }

    It "throws when the source is missing" {
        { Deploy-Config -Source (Join-Path $TestDrive "ghost") -Target (Join-Path $TestDrive "x") } |
            Should -Throw -ExpectedMessage "*Source config not found*"
    }
}

Describe "Test-Command" {
    It "returns true for a known built-in" {
        Test-Command "Get-ChildItem" | Should -BeTrue
    }
    It "returns false for a bogus name" {
        Test-Command "definitely-not-a-real-command-xyz" | Should -BeFalse
    }
}

Describe "Get-ScaffolderRoot" {
    It "resolves to the repo root (contains install-all.ps1)" {
        $root = Get-ScaffolderRoot
        Test-Path (Join-Path $root "install-all.ps1") | Should -BeTrue
        Test-Path (Join-Path $root "tools")           | Should -BeTrue
        Test-Path (Join-Path $root "configs")         | Should -BeTrue
    }
}
