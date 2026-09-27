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

Describe 'Get-OpenApiHttpClient' {
    It 'reuses the client of a service and applies the timeout' {
        InModuleScope -ModuleName tcs.openapi {
            $context = New-OpenApiContext -Service 'Cached' -BaseUri 'https://a' -TimeoutSec 42
            $first = Get-OpenApiHttpClient -Context $context
            $second = Get-OpenApiHttpClient -Context $context
            [object]::ReferenceEquals($first, $second) | Should -BeTrue
            $first.Timeout.TotalSeconds | Should -Be 42
            Clear-OpenApiHttpClientCache -Service 'Cached'
        }
    }

    It 'creates a new client when transport settings change, and none-timeout for 0' {
        InModuleScope -ModuleName tcs.openapi {
            $first = Get-OpenApiHttpClient -Context (New-OpenApiContext -Service 'Changing' -BaseUri 'https://a')
            $second = Get-OpenApiHttpClient -Context (New-OpenApiContext -Service 'Changing' -BaseUri 'https://a' -TimeoutSec 0)
            [object]::ReferenceEquals($first, $second) | Should -BeFalse
            $second.Timeout | Should -Be ([System.Threading.Timeout]::InfiniteTimeSpan)
            Clear-OpenApiHttpClientCache -Service 'Changing'
        }
    }
}
