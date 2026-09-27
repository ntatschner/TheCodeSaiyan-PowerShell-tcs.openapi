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

Describe 'Get-OpenApiLinkHeaderNext' {
    It 'finds rel="next" among several links' {
        InModuleScope -ModuleName tcs.openapi {
            Get-OpenApiLinkHeaderNext -LinkHeader '<https://a/x?page=1>; rel="prev", <https://a/x?page=3>; rel="next"' | Should -Be 'https://a/x?page=3'
            Get-OpenApiLinkHeaderNext -LinkHeader '</p2>; rel=next' | Should -Be '/p2'
            Get-OpenApiLinkHeaderNext -LinkHeader @('</a>; rel="prev"', '</b>; title="x"; rel="next last"') | Should -Be '/b'
        }
    }

    It 'returns $null without a next link' {
        InModuleScope -ModuleName tcs.openapi {
            Get-OpenApiLinkHeaderNext -LinkHeader '</p2>; rel="last"' | Should -BeNullOrEmpty
            Get-OpenApiLinkHeaderNext -LinkHeader $null | Should -BeNullOrEmpty
        }
    }
}
