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

Describe 'ConvertFrom-OpenApiJson' {
    It 'keeps arrays as arrays, including one-item and empty arrays' {
        InModuleScope -ModuleName tcs.openapi {
            $one = ConvertFrom-OpenApiJson -Text '[{"a":1}]'
            , $one | Should -BeOfType ([object[]])
            $one.Count | Should -Be 1
            $empty = ConvertFrom-OpenApiJson -Text '[]'
            , $empty | Should -BeOfType ([object[]])
            $empty.Count | Should -Be 0
        }
    }

    It 'parses objects and scalars and returns $null for empty text' {
        InModuleScope -ModuleName tcs.openapi {
            (ConvertFrom-OpenApiJson -Text '{"a":{"b":true}}').a.b | Should -BeTrue
            ConvertFrom-OpenApiJson -Text '"s"' | Should -Be 's'
            ConvertFrom-OpenApiJson -Text ' ' | Should -BeNullOrEmpty
        }
    }

    It 'throws for invalid JSON' {
        InModuleScope -ModuleName tcs.openapi {
            { ConvertFrom-OpenApiJson -Text '{nope' } | Should -Throw
        }
    }
}
