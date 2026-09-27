BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/New-TestOpenApiModel.ps1')
}

Describe 'Get-OpenApiGenMapEntry' {
    It 'keeps the order of an ordered dictionary' {
        $entries = InModuleScope tcs.openapi { @(Get-OpenApiGenMapEntry -Map ([ordered]@{ b = 1; a = 2 })) }
        $entries.Key | Should -Be @('b', 'a')
        $entries.Value | Should -Be @(1, 2)
    }

    It 'sorts a hashtable by key with an ordinal comparison' {
        $entries = InModuleScope tcs.openapi {
            $map = New-Object -TypeName System.Collections.Hashtable -ArgumentList ([System.StringComparer]::Ordinal)
            $map['b'] = 1
            $map['B'] = 3
            $map['a'] = 2
            @(Get-OpenApiGenMapEntry -Map $map)
        }
        $entries.Key | Should -BeExactly @('B', 'a', 'b')
    }

    It 'lists the properties of a PSCustomObject in order' {
        $entries = InModuleScope tcs.openapi { @(Get-OpenApiGenMapEntry -Map ([pscustomobject]@{ z = 1; y = 2 })) }
        $entries.Key | Should -Be @('z', 'y')
    }

    It 'returns nothing for $null' {
        InModuleScope tcs.openapi { @(Get-OpenApiGenMapEntry -Map $null).Count } | Should -Be 0
    }
}
