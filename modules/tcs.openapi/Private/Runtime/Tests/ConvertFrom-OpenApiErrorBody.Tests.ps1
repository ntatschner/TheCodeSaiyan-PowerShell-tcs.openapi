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

Describe 'ConvertFrom-OpenApiErrorBody' {
    It 'parses JSON and problem+json bodies' {
        InModuleScope -ModuleName tcs.openapi {
            (ConvertFrom-OpenApiErrorBody -Text '{"title":"t"}' -ContentType 'application/problem+json').title | Should -Be 't'
            (ConvertFrom-OpenApiErrorBody -Text '{"a":1}' -ContentType $null).a | Should -Be 1
        }
    }

    It 'returns text as it is and $null for an empty body' {
        InModuleScope -ModuleName tcs.openapi {
            ConvertFrom-OpenApiErrorBody -Text 'oops' -ContentType 'text/plain' | Should -Be 'oops'
            ConvertFrom-OpenApiErrorBody -Text '{broken' -ContentType 'application/json' | Should -Be '{broken'
            ConvertFrom-OpenApiErrorBody -Text '' -ContentType 'application/json' | Should -BeNullOrEmpty
        }
    }
}
