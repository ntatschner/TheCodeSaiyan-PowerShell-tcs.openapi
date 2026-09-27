BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/New-TestOpenApiModel.ps1')
}

Describe 'Test-OpenApiGenFunction' {
    It 'accepts a function that parses and binds and reports its parameters' {
        $result = InModuleScope tcs.openapi { Test-OpenApiGenFunction -Text "function Get-Probe {`n    [CmdletBinding()]`n    param([Parameter(ParameterSetName = 'A')][string]`$Name, [Parameter(ParameterSetName = 'B')][int]`$Id)`n}" -FunctionName 'Get-Probe' }
        $result.IsValid | Should -BeTrue
        $result.ParameterNames | Should -Contain 'Name'
        $result.ParameterSets | Should -Be @('A', 'B')
        $result.Syntax | Should -Match 'Get-Probe'
    }

    It 'rejects parse errors' {
        $result = InModuleScope tcs.openapi { Test-OpenApiGenFunction -Text 'function Get-Probe { param(' -FunctionName 'Get-Probe' }
        $result.IsValid | Should -BeFalse
        $result.Errors[0] | Should -Match 'Parse error'
    }

    It 'rejects a function that does not bind (duplicate alias)' {
        $result = InModuleScope tcs.openapi { Test-OpenApiGenFunction -Text "function Get-Probe {`n    [CmdletBinding()]`n    param([Alias('X')][string]`$A, [Alias('X')][string]`$B)`n}" -FunctionName 'Get-Probe' }
        $result.IsValid | Should -BeFalse
        $result.Errors[0] | Should -Match 'Bind check failed'
    }

    It 'rejects text with the wrong name or extra statements' {
        (InModuleScope tcs.openapi { Test-OpenApiGenFunction -Text 'function Get-Other { }' -FunctionName 'Get-Probe' }).IsValid | Should -BeFalse
        (InModuleScope tcs.openapi { Test-OpenApiGenFunction -Text "function Get-Probe { }`nRemove-Item -Path x" -FunctionName 'Get-Probe' }).IsValid | Should -BeFalse
    }

    It 'checks a function named like a cmdlet it uses and leaves no function behind' {
        $result = InModuleScope tcs.openapi { Test-OpenApiGenFunction -Text "function Get-Item {`n    [CmdletBinding()]`n    param([string]`$Name)`n}" -FunctionName 'Get-Item' }
        $result.IsValid | Should -BeTrue
        (Get-Command -Name Get-Item).CommandType | Should -Be 'Cmdlet'
        InModuleScope tcs.openapi { (Get-Command -Name Get-Item).CommandType } | Should -Be 'Cmdlet'
    }
}
