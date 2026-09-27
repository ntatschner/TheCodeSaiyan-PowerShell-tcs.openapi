BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/New-TestOpenApiModel.ps1')
}

Describe 'Get-OpenApiGenMapValue' {
    It 'reads a dictionary key' {
        InModuleScope tcs.openapi { Get-OpenApiGenMapValue -Map @{ 'x-ps-name' = 'Get-Thing' } -Key 'x-ps-name' } | Should -Be 'Get-Thing'
    }

    It 'reads a PSCustomObject property' {
        InModuleScope tcs.openapi { Get-OpenApiGenMapValue -Map ([pscustomobject]@{ Default = 'v1' }) -Key 'Default' } | Should -Be 'v1'
    }

    It 'returns $null for a missing key or a $null map' {
        InModuleScope tcs.openapi { Get-OpenApiGenMapValue -Map @{} -Key 'x' } | Should -BeNullOrEmpty
        InModuleScope tcs.openapi { Get-OpenApiGenMapValue -Map $null -Key 'x' } | Should -BeNullOrEmpty
    }

    It 'returns an array value as an array' {
        $value = InModuleScope tcs.openapi { $v = Get-OpenApiGenMapValue -Map @{ scopes = @('a', 'b') } -Key 'scopes'; , $v }
        $value.Count | Should -Be 2
    }
}
