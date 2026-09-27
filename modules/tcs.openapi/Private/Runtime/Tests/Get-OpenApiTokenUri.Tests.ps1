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

Describe 'Get-OpenApiTokenUri' {
    It 'prefers the context TokenUri, else the clientCredentials flow' {
        InModuleScope -ModuleName tcs.openapi {
            $scheme = @{ Type = 'oauth2'; Flows = @{ clientCredentials = @{ TokenUrl = 'https://flow/token' } } }
            Get-OpenApiTokenUri -Scheme $scheme -Context (Build-OpenApiContext -Service 'S' -BaseUri 'https://a' -TokenUri 'https://ctx/token') | Should -Be 'https://ctx/token'
            Get-OpenApiTokenUri -Scheme $scheme -Context (Build-OpenApiContext -Service 'S' -BaseUri 'https://a') | Should -Be 'https://flow/token'
            Get-OpenApiTokenUri -Scheme @{ Type = 'oauth2' } -Context (Build-OpenApiContext -Service 'S' -BaseUri 'https://a') | Should -BeNullOrEmpty
        }
    }
}
