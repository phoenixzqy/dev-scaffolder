# Run all Pester tests. Works with Pester 5+.
#Requires -Version 5.1
[CmdletBinding()] param(
    [switch]$CI
)

$here = $PSScriptRoot
Import-Module Pester -MinimumVersion 5.0 -Force

$cfg = New-PesterConfiguration
$cfg.Run.Path       = $here
$cfg.Run.Exit       = $CI.IsPresent
$cfg.Output.Verbosity = 'Detailed'
$cfg.TestResult.Enabled  = $true
$cfg.TestResult.OutputPath = Join-Path $here "TestResults.xml"

Invoke-Pester -Configuration $cfg
