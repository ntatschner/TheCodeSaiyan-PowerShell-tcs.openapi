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

Describe 'Add-OpenApiQueryString' {
    It 'adds pairs with ? or & and keeps a fragment at the end' {
        InModuleScope -ModuleName tcs.openapi {
            Add-OpenApiQueryString -Uri 'https://a/x' -Pair @('a=1', 'b=2') | Should -Be 'https://a/x?a=1&b=2'
            Add-OpenApiQueryString -Uri 'https://a/x?z=0' -Pair @('a=1') | Should -Be 'https://a/x?z=0&a=1'
            Add-OpenApiQueryString -Uri 'https://a/x?' -Pair @('a=1') | Should -Be 'https://a/x?a=1'
            Add-OpenApiQueryString -Uri 'https://a/x#top' -Pair @('a=1') | Should -Be 'https://a/x?a=1#top'
        }
    }

    It 'returns the URL unchanged when there are no pairs' {
        InModuleScope -ModuleName tcs.openapi {
            Add-OpenApiQueryString -Uri 'https://a/x' -Pair @() | Should -Be 'https://a/x'
            Add-OpenApiQueryString -Uri 'https://a/x' -Pair @('', $null) | Should -Be 'https://a/x'
        }
    }
}
