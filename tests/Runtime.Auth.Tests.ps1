BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $repoRoot = Split-Path -Path $PSScriptRoot -Parent
    Import-Module -Name (Join-Path -Path $repoRoot -ChildPath 'modules/tcs.openapi/tcs.openapi.psd1') -Force
    # Windows PowerShell 5.1 does not load System.Net.Http by default
    Add-Type -AssemblyName 'System.Net.Http'
    . (Join-Path -Path $PSScriptRoot -ChildPath 'Helpers/TestHttpServer.ps1')

    $script:server = Start-TestHttpServer -Routes @{
        'POST /token' = {
            param($Request)
            @{ Body = @{ access_token = "token-$([guid]::NewGuid().ToString('N').Substring(0, 8))"; token_type = 'Bearer'; expires_in = 3600 } }
        }
    } -Handler { param($Request) @{ Body = @{ ok = $true } } }

    function ConvertTo-TestSecret {
        param([string]$Text)
        $secure = New-Object System.Security.SecureString
        foreach ($character in $Text.ToCharArray()) {
            $secure.AppendChar($character)
        }
        return $secure
    }

    $script:schemes = @{
        headerKey = @{ Type = 'apiKey'; In = 'header'; ParameterName = 'X-API-Key' }
        queryKey  = @{ Type = 'apiKey'; In = 'query'; ParameterName = 'api_key' }
        cookieKey = @{ Type = 'apiKey'; In = 'cookie'; ParameterName = 'session' }
        basic     = @{ Type = 'http'; Scheme = 'basic' }
        bearer    = @{ Type = 'http'; Scheme = 'bearer'; BearerFormat = 'JWT' }
        oauth     = @{ Type = 'oauth2'; Flows = @{ clientCredentials = @{ TokenUrl = "$($script:server.BaseUri)/token"; Scopes = @{ 'pets.read' = 'Read pets' } } } }
    }
    function New-TestOperation {
        param($Security, [string]$Method = 'GET')
        $operation = @{
            OperationId     = 'getThing'
            Method          = $Method
            Path            = '/things'
            Parameters      = @()
            SecuritySchemes = $script:schemes
            Security        = $Security
        }
        return $operation
    }
}

AfterAll {
    $script:server.Stop()
    Remove-Module -Name tcs.openapi -Force -ErrorAction SilentlyContinue
}

Describe 'Invoke-OpenApiRequest authentication (end to end)' {
    BeforeEach {
        $script:server.Requests.Clear()
        Get-OpenApiContext | ForEach-Object -Process { Remove-OpenApiContext -Service $_.Service -Confirm:$false }
    }

    It 'sends an API key in a header' {
        Set-OpenApiContext -Service 'Auth' -BaseUri $script:server.BaseUri -ApiKey (ConvertTo-TestSecret -Text 'k-123')
        $null = Invoke-OpenApiRequest -Service 'Auth' -Operation (New-TestOperation -Security @(@{ headerKey = @() }))
        $script:server.Requests[0].Headers['X-API-Key'] | Should -Be 'k-123'
        $script:server.Requests[0].Headers['Authorization'] | Should -BeNullOrEmpty
    }

    It 'sends an API key in the query string' {
        Set-OpenApiContext -Service 'Auth' -BaseUri $script:server.BaseUri -ApiKey (ConvertTo-TestSecret -Text 'k 1/2')
        $null = Invoke-OpenApiRequest -Service 'Auth' -Operation (New-TestOperation -Security @(@{ queryKey = @() })) -QueryParameters @{ q = 'x' }
        $script:server.Requests[0].Query | Should -Be '?q=x&api_key=k%201%2F2'
    }

    It 'sends an API key as a cookie, joined with cookie parameters in one Cookie header' {
        Set-OpenApiContext -Service 'Auth' -BaseUri $script:server.BaseUri -ApiKey (ConvertTo-TestSecret -Text 'abc')
        $null = Invoke-OpenApiRequest -Service 'Auth' -Operation (New-TestOperation -Security @(@{ cookieKey = @() })) -CookieParameters @{ theme = 'dark' }
        $script:server.Requests[0].Headers['Cookie'] | Should -Be 'theme=dark; session=abc'
    }

    It 'sends HTTP basic credentials' {
        $credential = New-Object System.Management.Automation.PSCredential -ArgumentList 'user', (ConvertTo-TestSecret -Text 'p@ss')
        Set-OpenApiContext -Service 'Auth' -BaseUri $script:server.BaseUri -Credential $credential
        $null = Invoke-OpenApiRequest -Service 'Auth' -Operation (New-TestOperation -Security @(@{ basic = @() }))
        $expected = 'Basic ' + [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes('user:p@ss'))
        $script:server.Requests[0].Headers['Authorization'] | Should -Be $expected
    }

    It 'sends a bearer token' {
        Set-OpenApiContext -Service 'Auth' -BaseUri $script:server.BaseUri -BearerToken (ConvertTo-TestSecret -Text 'jwt.value')
        $null = Invoke-OpenApiRequest -Service 'Auth' -Operation (New-TestOperation -Security @(@{ bearer = @() }))
        $script:server.Requests[0].Headers['Authorization'] | Should -Be 'Bearer jwt.value'
    }

    It 'gets an OAuth2 client credentials token, caches it and sends it as a bearer token' {
        Set-OpenApiContext -Service 'Auth' -BaseUri $script:server.BaseUri -ClientId 'app' -ClientSecret (ConvertTo-TestSecret -Text 's3cret')
        $operation = New-TestOperation -Security @(@{ oauth = @('pets.read') })
        $null = Invoke-OpenApiRequest -Service 'Auth' -Operation $operation
        $null = Invoke-OpenApiRequest -Service 'Auth' -Operation $operation
        $tokenRequests = @($script:server.Requests | Where-Object -FilterScript { $_.Path -eq '/token' })
        $apiRequests = @($script:server.Requests | Where-Object -FilterScript { $_.Path -eq '/things' })
        $tokenRequests.Count | Should -Be 1
        $tokenRequests[0].Body | Should -Be 'grant_type=client_credentials&client_id=app&client_secret=s3cret&scope=pets.read'
        $tokenRequests[0].ContentType | Should -Be 'application/x-www-form-urlencoded'
        $apiRequests.Count | Should -Be 2
        $apiRequests[0].Headers['Authorization'] | Should -Match '^Bearer token-'
        $apiRequests[1].Headers['Authorization'] | Should -Be $apiRequests[0].Headers['Authorization']
    }

    It 'uses the context TokenUri and Scope over the scheme' {
        Set-OpenApiContext -Service 'Auth' -BaseUri $script:server.BaseUri -ClientId 'app' -ClientSecret (ConvertTo-TestSecret -Text 's') -TokenUri "$($script:server.BaseUri)/token?tenant=1" -Scope 'a', 'b'
        $null = Invoke-OpenApiRequest -Service 'Auth' -Operation (New-TestOperation -Security @(@{ oauth = @('pets.read') }))
        $script:server.Requests[0].Query | Should -Be '?tenant=1'
        $script:server.Requests[0].Body | Should -Match 'scope=a%20b$'
    }

    It 'requests a new token and retries once when the API answers 401' {
        Set-OpenApiContext -Service 'Auth' -BaseUri $script:server.BaseUri -ClientId 'app' -ClientSecret (ConvertTo-TestSecret -Text 's')
        $operation = New-TestOperation -Security @(@{ oauth = @() })
        $null = Invoke-OpenApiRequest -Service 'Auth' -Operation $operation
        $script:server.Requests.Clear()
        # The cached token is now rejected once
        $script:server.Enqueue(@{ StatusCode = 401; Body = @{ error = 'invalid_token' } })
        $result = Invoke-OpenApiRequest -Service 'Auth' -Operation $operation
        $result.ok | Should -BeTrue
        $paths = @($script:server.Requests | ForEach-Object -Process { $_.Path })
        $paths -join ',' | Should -Be '/things,/token,/things'
        $script:server.Requests[2].Headers['Authorization'] | Should -Not -Be $script:server.Requests[0].Headers['Authorization']
    }

    It 'refreshes only once: a second 401 is reported as an error' {
        Set-OpenApiContext -Service 'Auth' -BaseUri $script:server.BaseUri -ClientId 'app' -ClientSecret (ConvertTo-TestSecret -Text 's')
        $script:server.Enqueue({ param($Request) @{ Body = @{ access_token = 't1'; expires_in = 3600 } } })
        $script:server.Enqueue(@{ StatusCode = 401 })
        $script:server.Enqueue({ param($Request) @{ Body = @{ access_token = 't2'; expires_in = 3600 } } })
        $script:server.Enqueue(@{ StatusCode = 401 })
        $errors = $null
        $null = Invoke-OpenApiRequest -Service 'Auth' -Operation (New-TestOperation -Security @(@{ oauth = @() })) -ErrorAction SilentlyContinue -ErrorVariable errors
        $errors.Count | Should -Be 1
        $errors[0].FullyQualifiedErrorId | Should -BeLike 'OpenApi.Auth.401*'
        $script:server.Requests.Count | Should -Be 4
    }

    It 'reports a failed token request as an authentication error' {
        Set-OpenApiContext -Service 'Auth' -BaseUri $script:server.BaseUri -ClientId 'app' -ClientSecret (ConvertTo-TestSecret -Text 's')
        $script:server.Enqueue(@{ StatusCode = 400; Body = @{ error = 'invalid_client'; error_description = 'Unknown client' } })
        $errors = $null
        $null = Invoke-OpenApiRequest -Service 'Auth' -Operation (New-TestOperation -Security @(@{ oauth = @() })) -ErrorAction SilentlyContinue -ErrorVariable errors
        # -ErrorVariable also collects the exceptions caught inside the engine; the written error is the OpenApi one
        $errors = @($errors | Where-Object -FilterScript { $_.FullyQualifiedErrorId -like 'OpenApi.*' })
        $errors.Count | Should -Be 1
        $errors[0].FullyQualifiedErrorId | Should -BeLike 'OpenApi.Auth.Authentication*'
        $errors[0].CategoryInfo.Category | Should -Be 'AuthenticationError'
        $errors[0].Exception.Message | Should -Match 'invalid_client: Unknown client'
        $errors[0].Exception.Message | Should -Not -Match 's3cret'
    }

    It 'sends no credentials when the operation Security is empty' {
        Set-OpenApiContext -Service 'Auth' -BaseUri $script:server.BaseUri -ApiKey (ConvertTo-TestSecret -Text 'k') -BearerToken (ConvertTo-TestSecret -Text 't')
        $null = Invoke-OpenApiRequest -Service 'Auth' -Operation (New-TestOperation -Security @())
        $script:server.Requests[0].Headers['Authorization'] | Should -BeNullOrEmpty
        $script:server.Requests[0].Headers['X-API-Key'] | Should -BeNullOrEmpty
    }

    It 'picks the first requirement whose schemes all have credentials' {
        Set-OpenApiContext -Service 'Auth' -BaseUri $script:server.BaseUri -BearerToken (ConvertTo-TestSecret -Text 't')
        $security = @(@{ headerKey = @(); bearer = @() }, @{ bearer = @() })
        $null = Invoke-OpenApiRequest -Service 'Auth' -Operation (New-TestOperation -Security $security)
        $script:server.Requests[0].Headers['Authorization'] | Should -Be 'Bearer t'
        $script:server.Requests[0].Headers['X-API-Key'] | Should -BeNullOrEmpty
    }

    It 'applies every scheme of a requirement that needs several' {
        Set-OpenApiContext -Service 'Auth' -BaseUri $script:server.BaseUri -BearerToken (ConvertTo-TestSecret -Text 't') -ApiKey (ConvertTo-TestSecret -Text 'k')
        $null = Invoke-OpenApiRequest -Service 'Auth' -Operation (New-TestOperation -Security @(@{ headerKey = @(); bearer = @() }))
        $script:server.Requests[0].Headers['Authorization'] | Should -Be 'Bearer t'
        $script:server.Requests[0].Headers['X-API-Key'] | Should -Be 'k'
    }

    It 'uses the document default (DefaultSecurity) when Security is null' {
        Set-OpenApiContext -Service 'Auth' -BaseUri $script:server.BaseUri -ApiKey (ConvertTo-TestSecret -Text 'k')
        $operation = New-TestOperation -Security $null
        $operation['DefaultSecurity'] = @(@{ headerKey = @() })
        $null = Invoke-OpenApiRequest -Service 'Auth' -Operation $operation
        $script:server.Requests[0].Headers['X-API-Key'] | Should -Be 'k'
    }

    It 'uses a supplied bearer token for an OAuth2 scheme without fetching a token' {
        Set-OpenApiContext -Service 'Auth' -BaseUri $script:server.BaseUri -BearerToken (ConvertTo-TestSecret -Text 'given')
        $null = Invoke-OpenApiRequest -Service 'Auth' -Operation (New-TestOperation -Security @(@{ oauth = @() }))
        $script:server.Requests.Count | Should -Be 1
        $script:server.Requests[0].Headers['Authorization'] | Should -Be 'Bearer given'
    }

    It 'sends the request without credentials when no requirement can be met' {
        Set-OpenApiContext -Service 'Auth' -BaseUri $script:server.BaseUri
        $null = Invoke-OpenApiRequest -Service 'Auth' -Operation (New-TestOperation -Security @(@{ basic = @() }))
        $script:server.Requests[0].Headers['Authorization'] | Should -BeNullOrEmpty
    }

    It 'sends context headers with every request' {
        Set-OpenApiContext -Service 'Auth' -BaseUri $script:server.BaseUri -Header @{ 'X-Tenant' = 'contoso' }
        $null = Invoke-OpenApiRequest -Service 'Auth' -Operation (New-TestOperation -Security @())
        $script:server.Requests[0].Headers['X-Tenant'] | Should -Be 'contoso'
    }
}
