BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/New-TestOpenApiModel.ps1')
}

Describe 'Get-OpenApiGenOrdinalSorted' {
    It 'sorts strings ordinally (capitals before lower case)' {
        $sorted = InModuleScope tcs.openapi { Get-OpenApiGenOrdinalSorted -InputObject @('b', 'a', 'B', '_x') }
        $sorted | Should -Be @('B', '_x', 'a', 'b')
    }

    It 'sorts objects by a key and keeps equal keys in their order' {
        $sorted = InModuleScope tcs.openapi {
            Get-OpenApiGenOrdinalSorted -InputObject @(
                [pscustomobject]@{ K = 'b'; N = 1 }, [pscustomobject]@{ K = 'a'; N = 2 }, [pscustomobject]@{ K = 'b'; N = 3 }
            ) -Key { $_.K }
        }
        $sorted.N | Should -Be @(2, 1, 3)
    }

    It 'sorts a key that is a prefix of another first' {
        $sorted = InModuleScope tcs.openapi { Get-OpenApiGenOrdinalSorted -InputObject @('/pets/x', '/pets') }
        $sorted | Should -Be @('/pets', '/pets/x')
    }

    It 'returns an empty array for no input' {
        InModuleScope tcs.openapi { (Get-OpenApiGenOrdinalSorted -InputObject @()).Count } | Should -Be 0
    }
}
