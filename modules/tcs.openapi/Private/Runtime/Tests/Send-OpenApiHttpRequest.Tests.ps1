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

Describe 'Send-OpenApiHttpRequest' {
    BeforeAll {
        $script:server = Start-TestHttpServer -Handler { param($Request) @{ StatusCode = 202; Body = 'accepted'; ContentType = 'text/plain'; Headers = @{ 'X-Reply' = 'r' } } }
        InModuleScope -ModuleName tcs.openapi {
            $script:testClient = New-Object System.Net.Http.HttpClient
        }
    }

    AfterAll {
        InModuleScope -ModuleName tcs.openapi {
            $script:testClient.Dispose()
        }
        $script:server.Stop()
    }

    It 'sends method, headers and content and returns status, headers and the open message' {
        $response = InModuleScope -ModuleName tcs.openapi -Parameters @{ BaseUri = $script:server.BaseUri } {
            $factory = { Build-OpenApiHttpContent -Body 'hi' -ContentType 'text/plain' }
            Send-OpenApiHttpRequest -Client $script:testClient -Method 'patch' -Uri "$BaseUri/a?b=1" -Header ([ordered]@{ 'X-One' = '1'; 'Content-Language' = 'en' }) -ContentFactory $factory
        }
        $response.PSObject.TypeNames[0] | Should -Be 'Tcs.OpenApi.HttpResponse'
        $response.Method | Should -Be 'PATCH'
        $response.StatusCode | Should -Be 202
        $response.ReasonPhrase | Should -Be 'Accepted'
        $response.Headers['X-Reply'] | Should -Be 'r'
        $response.ContentType | Should -Be 'text/plain'
        $response.Message.Content.ReadAsStringAsync().GetAwaiter().GetResult() | Should -Be 'accepted'
        $response.Message.Dispose()
        $request = $script:server.Requests[0]
        $request.Method | Should -Be 'PATCH'
        $request.Headers['X-One'] | Should -Be '1'
        $request.Headers['Content-Language'] | Should -Be 'en'
        $request.Body | Should -Be 'hi'
    }

    It 'writes the request and status lines to Verbose with secrets redacted' {
        $verbose = InModuleScope -ModuleName tcs.openapi -Parameters @{ BaseUri = $script:server.BaseUri } {
            $response = Send-OpenApiHttpRequest -Client $script:testClient -Method 'GET' -Uri "$BaseUri/a?token=abc" -Verbose 4>&1
            $response | Where-Object -FilterScript { $_ -is [System.Management.Automation.VerboseRecord] }
            ($response | Where-Object -FilterScript { $_ -isnot [System.Management.Automation.VerboseRecord] }).Message.Dispose()
        }
        $verbose[0].Message | Should -Be "GET $($script:server.BaseUri)/a?token=********"
        $verbose[1].Message | Should -Match '-> 202 Accepted \(\d+ ms\)$'
    }

    It 'rethrows transport failures as the underlying exception' {
        InModuleScope -ModuleName tcs.openapi {
            $probe = New-Object System.Net.Sockets.TcpListener -ArgumentList ([System.Net.IPAddress]::Loopback), 0
            $probe.Start()
            $port = ([System.Net.IPEndPoint]$probe.LocalEndpoint).Port
            $probe.Stop()
            { Send-OpenApiHttpRequest -Client $script:testClient -Method 'GET' -Uri "http://127.0.0.1:$port/" } | Should -Throw -ExceptionType ([System.Net.Http.HttpRequestException])
        }
    }
}
