BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/TestHttpServer.ps1')
}

AfterAll {
    Remove-Module -Name tcs.openapi -Force -ErrorAction SilentlyContinue
}

Describe 'Get-OpenApiOAuthToken' {
    BeforeAll {
        $script:server = Start-TestHttpServer -Routes @{
            'POST /token'  = { param($Request) @{ Body = @{ access_token = "tok-$([guid]::NewGuid().ToString('N'))"; expires_in = 3600 } } }
            'POST /short'  = { param($Request) @{ Body = @{ access_token = "tok-$([guid]::NewGuid().ToString('N'))"; expires_in = 30 } } }
            'POST /denied' = @{ StatusCode = 401; Body = @{ error = 'invalid_client' } }
            'POST /empty'  = @{ Body = @{ token_type = 'Bearer' } }
        }
        InModuleScope -ModuleName tcs.openapi -Parameters @{ BaseUri = $script:server.BaseUri } {
            $script:testClient = New-Object System.Net.Http.HttpClient
            $script:testContext = Build-OpenApiContext -Service 'Tok' -BaseUri $BaseUri -ClientId 'id' -ClientSecret (ConvertTo-SecureString -String 'sec' -AsPlainText -Force)
        }
    }

    AfterAll {
        InModuleScope -ModuleName tcs.openapi {
            $script:testClient.Dispose()
        }
        $script:server.Stop()
    }

    It 'posts client credentials and caches the token' {
        InModuleScope -ModuleName tcs.openapi -Parameters @{ BaseUri = $script:server.BaseUri } {
            Clear-OpenApiTokenCache
            $first = Get-OpenApiOAuthToken -Context $script:testContext -Client $script:testClient -TokenUri "$BaseUri/token" -Scope 'a', 'b'
            $second = Get-OpenApiOAuthToken -Context $script:testContext -Client $script:testClient -TokenUri "$BaseUri/token" -Scope 'a', 'b'
            $first | Should -BeOfType ([System.Security.SecureString])
            (ConvertFrom-OpenApiSecureString -SecureString $second) | Should -Be (ConvertFrom-OpenApiSecureString -SecureString $first)
            $forced = Get-OpenApiOAuthToken -Context $script:testContext -Client $script:testClient -TokenUri "$BaseUri/token" -Scope 'a', 'b' -Force
            (ConvertFrom-OpenApiSecureString -SecureString $forced) | Should -Not -Be (ConvertFrom-OpenApiSecureString -SecureString $first)
        }
        @($script:server.Requests | Where-Object -FilterScript { $_.Path -eq '/token' }).Count | Should -Be 2
        $script:server.Requests[0].Body | Should -Be 'grant_type=client_credentials&client_id=id&client_secret=sec&scope=a%20b'
    }

    It 'does not reuse a token within 60 seconds of expiry' {
        InModuleScope -ModuleName tcs.openapi -Parameters @{ BaseUri = $script:server.BaseUri } {
            $first = Get-OpenApiOAuthToken -Context $script:testContext -Client $script:testClient -TokenUri "$BaseUri/short"
            $second = Get-OpenApiOAuthToken -Context $script:testContext -Client $script:testClient -TokenUri "$BaseUri/short"
            (ConvertFrom-OpenApiSecureString -SecureString $second) | Should -Not -Be (ConvertFrom-OpenApiSecureString -SecureString $first)
        }
    }

    It 'throws AuthenticationException for a failed or empty token response' {
        InModuleScope -ModuleName tcs.openapi -Parameters @{ BaseUri = $script:server.BaseUri } {
            { Get-OpenApiOAuthToken -Context $script:testContext -Client $script:testClient -TokenUri "$BaseUri/denied" } | Should -Throw -ExceptionType ([System.Security.Authentication.AuthenticationException]) -ExpectedMessage '*401*invalid_client*'
            { Get-OpenApiOAuthToken -Context $script:testContext -Client $script:testClient -TokenUri "$BaseUri/empty" } | Should -Throw -ExpectedMessage '*no access_token*'
        }
    }
}
