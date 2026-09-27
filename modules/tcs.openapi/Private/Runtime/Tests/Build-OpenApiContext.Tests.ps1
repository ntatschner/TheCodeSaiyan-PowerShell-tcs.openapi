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

Describe 'Build-OpenApiContext' {
    It 'creates a context with defaults and a trimmed base URI' {
        InModuleScope -ModuleName tcs.openapi {
            $context = Build-OpenApiContext -Service 'Svc' -BaseUri 'https://api.example.com/v1/'
            $context.PSObject.TypeNames[0] | Should -Be 'Tcs.OpenApi.ContextData'
            $context.BaseUri | Should -Be 'https://api.example.com/v1'
            $context.TimeoutSec | Should -Be 100
            $context.MaxRetries | Should -Be 3
            $context.Scope.Count | Should -Be 0
            $context.Header.Count | Should -Be 0
            $context.ClientId | Should -BeNullOrEmpty
            $context.Proxy | Should -BeNullOrEmpty
        }
    }

    It 'copies headers as strings and keeps secrets as SecureString' {
        InModuleScope -ModuleName tcs.openapi {
            $key = ConvertTo-SecureString -String 'k' -AsPlainText -Force
            $context = Build-OpenApiContext -Service 'Svc' -BaseUri 'https://a' -ApiKey $key -Header @{ 'X-Num' = 5 } -Scope @('a', '', 'b')
            $context.ApiKey | Should -BeOfType ([System.Security.SecureString])
            $context.Header['X-Num'] | Should -BeExactly '5'
            $context.Scope | Should -Be @('a', 'b')
        }
    }
}
