BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    # Windows PowerShell 5.1 does not load System.Net.Http by default
    Add-Type -AssemblyName 'System.Net.Http'
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/TestHttpServer.ps1')
}

AfterAll {
    Remove-Module -Name tcs.openapi -Force -ErrorAction SilentlyContinue
}

Describe 'Invoke-OpenApiHttpExchange' {
    BeforeAll {
        $script:server = Start-TestHttpServer -Handler { param($Request) @{ Body = @{ ok = $true } } }
        InModuleScope -ModuleName tcs.openapi -Parameters @{ BaseUri = $script:server.BaseUri } {
            $script:testContext = New-OpenApiContext -Service 'Ex' -BaseUri $BaseUri -ApiKey ((New-Object -TypeName System.Net.NetworkCredential -ArgumentList '', 'k').SecurePassword) -MaxRetries 2
            $script:testClient = Get-OpenApiHttpClient -Context $script:testContext
            $script:testOperation = @{ Security = @(@{ q = @() }); SecuritySchemes = @{ q = @{ Type = 'apiKey'; In = 'query'; ParameterName = 'key' } } }
        }
        Mock -ModuleName tcs.openapi -CommandName Get-OpenApiRetryPolicy -MockWith {
            [pscustomobject]@{ StatusCodes = @(429, 503); MaxRetries = $MaxRetries; DelaySeconds = 0; BackoffMultiplier = 1; MaxDelaySeconds = 1; JitterPercent = 0; RetryConnectionFailure = $false }
        }
    }

    AfterAll {
        $script:server.Stop()
    }

    BeforeEach {
        $script:server.Requests.Clear()
    }

    It 'adds auth to the request and returns the response with an unread body' {
        $response = InModuleScope -ModuleName tcs.openapi -Parameters @{ BaseUri = $script:server.BaseUri } {
            Invoke-OpenApiHttpExchange -Context $script:testContext -Operation $script:testOperation -Client $script:testClient -Method 'GET' -Uri "$BaseUri/x" -Header @{ 'X-A' = '1' } -Cookie @('c=1')
        }
        $response.StatusCode | Should -Be 200
        $response.Message | Should -Not -BeNullOrEmpty
        $response.Message.Dispose()
        $script:server.Requests[0].Query | Should -Be '?key=k'
        $script:server.Requests[0].Headers['X-A'] | Should -Be '1'
        $script:server.Requests[0].Headers['Cookie'] | Should -Be 'c=1'
    }

    It 'does not add query credentials a next-page link already has' {
        $null = InModuleScope -ModuleName tcs.openapi -Parameters @{ BaseUri = $script:server.BaseUri } {
            $response = Invoke-OpenApiHttpExchange -Context $script:testContext -Operation $script:testOperation -Client $script:testClient -Method 'GET' -Uri "$BaseUri/x?page=2&key=k"
            $response.Message.Dispose()
        }
        $script:server.Requests[0].Query | Should -Be '?page=2&key=k'
    }

    It 'retries retryable statuses and returns the last response when retries are used up' {
        foreach ($i in 1..3) {
            $script:server.Enqueue(@{ StatusCode = 503; Body = "busy $i" })
        }
        $response = InModuleScope -ModuleName tcs.openapi -Parameters @{ BaseUri = $script:server.BaseUri } {
            Invoke-OpenApiHttpExchange -Context $script:testContext -Operation $script:testOperation -Client $script:testClient -Method 'GET' -Uri "$BaseUri/x"
        }
        $response.StatusCode | Should -Be 503
        [System.Text.Encoding]::UTF8.GetString($response.Body) | Should -Be 'busy 3'
        $script:server.Requests.Count | Should -Be 3
    }

    It 'rebuilds the body for every attempt' {
        $script:server.Enqueue(@{ StatusCode = 429 })
        $null = InModuleScope -ModuleName tcs.openapi -Parameters @{ BaseUri = $script:server.BaseUri } {
            $factory = { New-OpenApiHttpContent -Body @{ a = 1 } -ContentType 'application/json' }
            $response = Invoke-OpenApiHttpExchange -Context $script:testContext -Operation $script:testOperation -Client $script:testClient -Method 'POST' -Uri "$BaseUri/x" -ContentFactory $factory
            $response.Message.Dispose()
        }
        $script:server.Requests.Count | Should -Be 2
        $script:server.Requests[1].Body | Should -Be '{"a":1}'
    }

    It 'throws transport failures' {
        InModuleScope -ModuleName tcs.openapi {
            $probe = New-Object System.Net.Sockets.TcpListener -ArgumentList ([System.Net.IPAddress]::Loopback), 0
            $probe.Start()
            $port = ([System.Net.IPEndPoint]$probe.LocalEndpoint).Port
            $probe.Stop()
            { Invoke-OpenApiHttpExchange -Context $script:testContext -Operation @{ Security = @() } -Client $script:testClient -Method 'GET' -Uri "http://127.0.0.1:$port/" } | Should -Throw -ExceptionType ([System.Net.Http.HttpRequestException])
        }
    }
}
