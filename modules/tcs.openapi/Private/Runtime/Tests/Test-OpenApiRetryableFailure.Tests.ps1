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

Describe 'Test-OpenApiRetryableFailure' {
    It 'always retries HTTP responses and transport failures only for idempotent methods' {
        InModuleScope -ModuleName tcs.openapi {
            $idempotent = [pscustomobject]@{ RetryConnectionFailure = $true }
            $nonIdempotent = [pscustomobject]@{ RetryConnectionFailure = $false }
            $response = [pscustomobject]@{ Method = 'POST'; StatusCode = 429; ReasonPhrase = 'x'; Headers = @{}; Message = $null; Body = [byte[]]@() }
            $httpFailure = Build-OpenApiRetryException -Response $response
            Test-OpenApiRetryableFailure -ErrorRecord $httpFailure -Policy $nonIdempotent | Should -BeTrue

            $transport = New-Object System.Net.Http.HttpRequestException -ArgumentList 'refused'
            $record = New-Object System.Management.Automation.ErrorRecord -ArgumentList $transport, 'x', 'ConnectionError', $null
            Test-OpenApiRetryableFailure -ErrorRecord $record -Policy $idempotent | Should -BeTrue
            Test-OpenApiRetryableFailure -ErrorRecord $record -Policy $nonIdempotent | Should -BeFalse
            Test-OpenApiRetryableFailure -ErrorRecord (New-Object System.TimeoutException) -Policy $idempotent | Should -BeTrue
        }
    }

    It 'does not retry other errors' {
        InModuleScope -ModuleName tcs.openapi {
            Test-OpenApiRetryableFailure -ErrorRecord (New-Object System.ArgumentException) -Policy ([pscustomobject]@{ RetryConnectionFailure = $true }) | Should -BeFalse
        }
    }
}
