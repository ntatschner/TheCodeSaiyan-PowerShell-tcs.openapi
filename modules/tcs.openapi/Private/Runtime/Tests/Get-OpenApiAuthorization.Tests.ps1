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

Describe 'Get-OpenApiAuthorization' {
    BeforeAll {
        InModuleScope -ModuleName tcs.openapi {
            $script:testClient = New-Object System.Net.Http.HttpClient
        }
    }

    AfterAll {
        InModuleScope -ModuleName tcs.openapi {
            $script:testClient.Dispose()
        }
    }

    It 'returns header, query and cookie credentials for the selected schemes' {
        InModuleScope -ModuleName tcs.openapi {
            $key = ConvertTo-SecureString -String 'k 1' -AsPlainText -Force
            $context = Build-OpenApiContext -Service 'S' -BaseUri 'https://a' -ApiKey $key
            $schemes = @{
                h = @{ Type = 'apiKey'; In = 'header'; ParameterName = 'X-Key' }
                q = @{ Type = 'apiKey'; In = 'query'; ParameterName = 'key' }
                c = @{ Type = 'apiKey'; In = 'cookie'; ParameterName = 'sid' }
            }
            $operation = @{ Security = @(@{ h = @(); q = @(); c = @() }); SecuritySchemes = $schemes }
            $auth = Get-OpenApiAuthorization -Operation $operation -Context $context -Client $script:testClient
            $auth.Header['X-Key'] | Should -Be 'k 1'
            $auth.Query | Should -Be @('key=k%201')
            $auth.Cookie | Should -Be @('sid=k%201')
            $auth.SensitiveName | Should -Contain 'X-Key'
            $auth.UsesOAuth | Should -BeFalse
        }
    }

    It 'falls back to the context bearer token or credential without security metadata' {
        InModuleScope -ModuleName tcs.openapi {
            $token = ConvertTo-SecureString -String 't' -AsPlainText -Force
            $auth = Get-OpenApiAuthorization -Operation @{ OperationId = 'x' } -Context (Build-OpenApiContext -Service 'S' -BaseUri 'https://a' -BearerToken $token) -Client $script:testClient
            $auth.Header['Authorization'] | Should -Be 'Bearer t'
            $credential = New-Object System.Management.Automation.PSCredential -ArgumentList 'u', $token
            $auth = Get-OpenApiAuthorization -Operation @{ OperationId = 'x' } -Context (Build-OpenApiContext -Service 'S' -BaseUri 'https://a' -Credential $credential) -Client $script:testClient
            $auth.Header['Authorization'] | Should -Be ('Basic ' + [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes('u:t')))
        }
    }

    It 'fetches an OAuth2 token for an oauth2 scheme' {
        InModuleScope -ModuleName tcs.openapi {
            Mock -CommandName Get-OpenApiOAuthToken -MockWith { ConvertTo-SecureString -String "fetched-$Force" -AsPlainText -Force }
            $secret = ConvertTo-SecureString -String 's' -AsPlainText -Force
            $context = Build-OpenApiContext -Service 'S' -BaseUri 'https://a' -ClientId 'id' -ClientSecret $secret -TokenUri 'https://t/token'
            $operation = @{ Security = @(@{ o = @('read') }); SecuritySchemes = @{ o = @{ Type = 'oauth2' } } }
            $auth = Get-OpenApiAuthorization -Operation $operation -Context $context -Client $script:testClient -ForceRefresh
            $auth.Header['Authorization'] | Should -Be 'Bearer fetched-True'
            $auth.UsesOAuth | Should -BeTrue
            Should -Invoke -CommandName Get-OpenApiOAuthToken -Times 1 -ParameterFilter { $TokenUri -eq 'https://t/token' -and ($Scope -join ',') -eq 'read' }
        }
    }

    It 'returns no credentials for Security = []' {
        InModuleScope -ModuleName tcs.openapi {
            $token = ConvertTo-SecureString -String 't' -AsPlainText -Force
            $auth = Get-OpenApiAuthorization -Operation @{ Security = @() } -Context (Build-OpenApiContext -Service 'S' -BaseUri 'https://a' -BearerToken $token) -Client $script:testClient
            $auth.Header.Count | Should -Be 0
            $auth.Query.Count | Should -Be 0
        }
    }
}
