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

Describe 'Build-OpenApiRetryException' {
    It 'exposes the status code and Retry-After to tcs.core' {
        InModuleScope -ModuleName tcs.openapi {
            $response = [pscustomobject]@{ Method = 'GET'; Uri = 'https://a'; StatusCode = 429; ReasonPhrase = 'Too Many Requests'; Headers = @{ 'Retry-After' = '7' }; ContentType = $null; Message = $null; Body = [byte[]]@() }
            $exception = Build-OpenApiRetryException -Response $response
            $exception | Should -BeOfType ([System.Net.Http.HttpRequestException])
            $exception.TcsOpenApiResponse | Should -Be $response
            $detail = Get-HttpErrorDetail -ErrorRecord $exception
            $detail.StatusCode | Should -Be 429
            $detail.RetryAfterSeconds | Should -Be 7
        }
    }
}
