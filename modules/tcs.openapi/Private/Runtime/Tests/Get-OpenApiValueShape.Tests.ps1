BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
}

AfterAll {
    Remove-Module -Name tcs.openapi -Force -ErrorAction SilentlyContinue
}

Describe 'Get-OpenApiValueShape' {
    It 'classifies values' {
        InModuleScope -ModuleName tcs.openapi {
            Get-OpenApiValueShape -Value $null | Should -Be 'Empty'
            Get-OpenApiValueShape -Value '' | Should -Be 'Empty'
            Get-OpenApiValueShape -Value @() | Should -Be 'Empty'
            Get-OpenApiValueShape -Value 'x' | Should -Be 'Scalar'
            Get-OpenApiValueShape -Value 0 | Should -Be 'Scalar'
            Get-OpenApiValueShape -Value $false | Should -Be 'Scalar'
            Get-OpenApiValueShape -Value @(1) | Should -Be 'Array'
            Get-OpenApiValueShape -Value (New-Object System.Collections.Generic.List[int]) | Should -Be 'Empty'
            Get-OpenApiValueShape -Value @{ a = 1 } | Should -Be 'Object'
            Get-OpenApiValueShape -Value ([pscustomobject]@{ a = 1 }) | Should -Be 'Object'
        }
    }
}
