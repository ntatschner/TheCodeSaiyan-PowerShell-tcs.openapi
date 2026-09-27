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

Describe 'New-OpenApiErrorRecord' {
    It 'builds an HTTP error record from a response' {
        InModuleScope -ModuleName tcs.openapi {
            $response = [pscustomobject]@{
                Method = 'GET'; Uri = 'https://a/x'; StatusCode = 403; ReasonPhrase = 'Forbidden'
                Headers = @{ 'Content-Type' = 'application/problem+json' }; ContentType = 'application/problem+json'; Message = $null
                Body = [System.Text.Encoding]::UTF8.GetBytes('{"title":"Denied","detail":"No access."}')
            }
            $record = New-OpenApiErrorRecord -Service 'Svc' -OperationId 'op' -Method 'GET' -Uri 'https://a/x?api_key=secret' -Response $response -SensitiveName 'api_key'
            $record.FullyQualifiedErrorId | Should -Be 'OpenApi.Svc.403'
            $record.CategoryInfo.Category | Should -Be 'PermissionDenied'
            $record.Exception | Should -BeOfType ([System.Net.Http.HttpRequestException])
            $record.Exception.Message | Should -Match 'Denied: No access\.'
            $record.Exception.Message | Should -Not -Match 'secret'
            $record.TargetObject.Uri | Should -Be 'https://a/x?api_key=********'
            $record.TargetObject.Body.detail | Should -Be 'No access.'
            $record.TargetObject.OperationId | Should -Be 'op'
            $record.TargetObject.StatusCode | Should -Be 403
        }
    }

    It 'builds a record for an exception with the given kind and category' {
        InModuleScope -ModuleName tcs.openapi {
            $exception = New-Object System.Net.Http.HttpRequestException -ArgumentList 'refused'
            $record = New-OpenApiErrorRecord -Service 'Svc' -Method 'GET' -Uri 'https://a' -Exception $exception -Kind 'Connection' -Category ConnectionError
            $record.FullyQualifiedErrorId | Should -Be 'OpenApi.Svc.Connection'
            $record.CategoryInfo.Category | Should -Be 'ConnectionError'
            $record.Exception.Message | Should -Be 'refused'
            $record.TargetObject.StatusCode | Should -BeNullOrEmpty
        }
    }
}
