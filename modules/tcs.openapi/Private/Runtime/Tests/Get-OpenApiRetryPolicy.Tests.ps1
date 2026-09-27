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

Describe 'Get-OpenApiRetryPolicy' {
    It 'retries only 429 and 503, and no transport failures, for <Method>' -ForEach @(
        @{ Method = 'POST' }
        @{ Method = 'patch' }
    ) {
        InModuleScope -ModuleName tcs.openapi -Parameters @{ Method = $Method } {
            $policy = Get-OpenApiRetryPolicy -Method $Method -MaxRetries 3
            $policy.StatusCodes | Should -Be @(429, 503)
            $policy.RetryConnectionFailure | Should -BeFalse
        }
    }

    It 'retries 408, 429 and 5xx for idempotent <Method>' -ForEach @(
        @{ Method = 'GET' }
        @{ Method = 'PUT' }
        @{ Method = 'DELETE' }
        @{ Method = 'HEAD' }
        @{ Method = 'OPTIONS' }
    ) {
        InModuleScope -ModuleName tcs.openapi -Parameters @{ Method = $Method } {
            $policy = Get-OpenApiRetryPolicy -Method $Method -MaxRetries 5
            $policy.StatusCodes | Should -Be @(408, 429, 500, 502, 503, 504)
            $policy.MaxRetries | Should -Be 5
            $policy.RetryConnectionFailure | Should -BeTrue
        }
    }
}
