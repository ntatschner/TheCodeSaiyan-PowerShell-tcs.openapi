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

Describe 'Test-OpenApiSensitiveName' {
    It 'treats <Name> as sensitive: <Expected>' -ForEach @(
        @{ Name = 'Authorization'; Expected = $true }
        @{ Name = 'proxy-authorization'; Expected = $true }
        @{ Name = 'Cookie'; Expected = $true }
        @{ Name = 'Set-Cookie'; Expected = $true }
        @{ Name = 'X-API-Key'; Expected = $true }
        @{ Name = 'apikey'; Expected = $true }
        @{ Name = 'client_secret'; Expected = $true }
        @{ Name = 'refreshToken'; Expected = $true }
        @{ Name = 'Password'; Expected = $true }
        @{ Name = 'Accept'; Expected = $false }
        @{ Name = 'X-Request-Id'; Expected = $false }
        @{ Name = ''; Expected = $false }
    ) {
        InModuleScope -ModuleName tcs.openapi -Parameters @{ Name = $Name; Expected = $Expected } {
            Test-OpenApiSensitiveName -Name $Name | Should -Be $Expected
        }
    }

    It 'treats listed names as sensitive' {
        InModuleScope -ModuleName tcs.openapi {
            Test-OpenApiSensitiveName -Name 'sig' -SensitiveName @('sig') | Should -BeTrue
        }
    }
}
