BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    # Windows PowerShell 5.1 does not load System.Net.Http by default
    Add-Type -AssemblyName 'System.Net.Http'
}

AfterAll {
    Remove-Module -Name tcs.openapi -Force -ErrorAction SilentlyContinue
}

Describe 'ConvertFrom-OpenApiResponseJson' {
    It 'keeps arrays as arrays, including one-item and empty arrays' {
        InModuleScope -ModuleName tcs.openapi {
            $one = ConvertFrom-OpenApiResponseJson -Text '[{"a":1}]'
            , $one | Should -BeOfType ([object[]])
            $one.Count | Should -Be 1
            $empty = ConvertFrom-OpenApiResponseJson -Text '[]'
            , $empty | Should -BeOfType ([object[]])
            $empty.Count | Should -Be 0
        }
    }

    It 'parses objects and scalars and returns $null for empty text' {
        InModuleScope -ModuleName tcs.openapi {
            (ConvertFrom-OpenApiResponseJson -Text '{"a":{"b":true}}').a.b | Should -BeTrue
            ConvertFrom-OpenApiResponseJson -Text '"s"' | Should -Be 's'
            ConvertFrom-OpenApiResponseJson -Text ' ' | Should -BeNullOrEmpty
        }
    }

    It 'throws for invalid JSON' {
        InModuleScope -ModuleName tcs.openapi {
            { ConvertFrom-OpenApiResponseJson -Text '{nope' } | Should -Throw
        }
    }
}
