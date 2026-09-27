BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $repoRoot = Split-Path -Path $PSScriptRoot -Parent
    Import-Module -Name (Join-Path -Path $repoRoot -ChildPath 'modules/tcs.openapi/tcs.openapi.psd1') -Force
    # Windows PowerShell 5.1 does not load System.Net.Http by default
    Add-Type -AssemblyName 'System.Net.Http'
    . (Join-Path -Path $PSScriptRoot -ChildPath 'Helpers/TestHttpServer.ps1')
    $script:server = Start-TestHttpServer -Handler { param($Request) @{ Body = @{ ok = $true } } }
    Set-OpenApiContext -Service 'Retry' -BaseUri $script:server.BaseUri -MaxRetries 2

    function New-TestOperation {
        param([string]$Method = 'GET')
        return @{ OperationId = 'op'; Method = $Method; Path = '/r'; Security = @(); RequestContentTypes = @('application/json') }
    }
}

AfterAll {
    $script:server.Stop()
    Remove-Module -Name tcs.openapi -Force -ErrorAction SilentlyContinue
}

Describe 'Invoke-OpenApiRequest retries (end to end)' {
    BeforeAll {
        # No base delay or jitter, so only Retry-After makes the engine wait
        Mock -ModuleName tcs.openapi -CommandName Get-OpenApiRetryPolicy -MockWith {
            $idempotent = @('GET', 'HEAD', 'OPTIONS', 'PUT', 'DELETE', 'TRACE') -contains $Method.ToUpperInvariant()
            $codes = @(429, 503)
            if ($idempotent) {
                $codes = @(408, 429, 500, 502, 503, 504)
            }
            [pscustomobject]@{ StatusCodes = $codes; MaxRetries = $MaxRetries; DelaySeconds = 0; BackoffMultiplier = 1; MaxDelaySeconds = 10; JitterPercent = 0; RetryConnectionFailure = $idempotent }
        }
    }

    BeforeEach {
        $script:server.Requests.Clear()
    }

    It 'retries a 429 after the Retry-After delay and returns the successful response' {
        $script:server.Enqueue(@{ StatusCode = 429; Headers = @{ 'Retry-After' = '1' }; Body = 'slow down'; ContentType = 'text/plain' })
        $watch = [System.Diagnostics.Stopwatch]::StartNew()
        $result = Invoke-OpenApiRequest -Service 'Retry' -Operation (New-TestOperation)
        $watch.Stop()
        $result.ok | Should -BeTrue
        $script:server.Requests.Count | Should -Be 2
        $watch.Elapsed.TotalMilliseconds | Should -BeGreaterOrEqual 900
        $gap = ($script:server.Requests[1].ReceivedAt - $script:server.Requests[0].ReceivedAt).TotalMilliseconds
        $gap | Should -BeGreaterOrEqual 900
    }

    It 'retries 500/502/503/504/408 for idempotent methods' {
        foreach ($code in 500, 502, 504) {
            $script:server.Enqueue(@{ StatusCode = $code })
        }
        $result = Invoke-OpenApiRequest -Service 'Retry' -Operation (New-TestOperation -Method 'PUT') -Body @{ a = 1 } -ErrorAction SilentlyContinue
        # MaxRetries is 2: three attempts, all failed
        $script:server.Requests.Count | Should -Be 3
        $result | Should -BeNullOrEmpty
        $script:server.Requests[2].Body | Should -Be '{"a":1}'
    }

    It 'sends a stream body again on a retry and leaves the stream open' {
        $bytes = [byte[]](10, 20, 30, 40)
        $stream = New-Object System.IO.MemoryStream -ArgumentList (, $bytes)
        $script:server.Enqueue(@{ StatusCode = 503 })
        $operation = @{ OperationId = 'up'; Method = 'PUT'; Path = '/r'; Security = @(); RequestContentTypes = @('application/octet-stream') }
        $result = Invoke-OpenApiRequest -Service 'Retry' -Operation $operation -Body $stream
        $result.ok | Should -BeTrue
        $script:server.Requests.Count | Should -Be 2
        $script:server.Requests[0].BodyBytes | Should -Be $bytes
        $script:server.Requests[1].BodyBytes | Should -Be $bytes
        $stream.CanRead | Should -BeTrue
        $stream.Dispose()
    }

    It 'retries only 429 and 503 for POST' {
        $script:server.Enqueue(@{ StatusCode = 503 })
        $result = Invoke-OpenApiRequest -Service 'Retry' -Operation (New-TestOperation -Method 'POST') -Body @{ a = 1 }
        $result.ok | Should -BeTrue
        $script:server.Requests.Count | Should -Be 2
        $script:server.Requests[1].Body | Should -Be '{"a":1}'

        $script:server.Requests.Clear()
        $script:server.Enqueue(@{ StatusCode = 500 })
        $errors = $null
        $null = Invoke-OpenApiRequest -Service 'Retry' -Operation (New-TestOperation -Method 'PATCH') -Body @{ a = 1 } -ErrorAction SilentlyContinue -ErrorVariable errors
        $script:server.Requests.Count | Should -Be 1
        @($errors | Where-Object -FilterScript { $_.FullyQualifiedErrorId -like 'OpenApi.Retry.500*' }).Count | Should -Be 1
    }

    It 'does not retry client errors' {
        $script:server.Enqueue(@{ StatusCode = 400 })
        $null = Invoke-OpenApiRequest -Service 'Retry' -Operation (New-TestOperation) -ErrorAction SilentlyContinue
        $script:server.Requests.Count | Should -Be 1
    }

    It 'reports the last status when retries are used up' {
        foreach ($i in 1..3) {
            $script:server.Enqueue(@{ StatusCode = 429; Body = @{ title = 'Too many requests'; detail = "attempt $i" }; ContentType = 'application/problem+json' })
        }
        $errors = $null
        $null = Invoke-OpenApiRequest -Service 'Retry' -Operation (New-TestOperation) -ErrorAction SilentlyContinue -ErrorVariable errors
        $record = @($errors | Where-Object -FilterScript { $_.FullyQualifiedErrorId -like 'OpenApi.*' })
        $record.Count | Should -Be 1
        $record[0].FullyQualifiedErrorId | Should -BeLike 'OpenApi.Retry.429*'
        $record[0].CategoryInfo.Category | Should -Be 'LimitsExceeded'
        $record[0].Exception.Message | Should -Match 'Too many requests: attempt 3'
        $script:server.Requests.Count | Should -Be 3
    }

    It 'takes MaxRetries from the context' {
        Set-OpenApiContext -Service 'NoRetry' -BaseUri $script:server.BaseUri -MaxRetries 0
        $script:server.Enqueue(@{ StatusCode = 503 })
        $null = Invoke-OpenApiRequest -Service 'NoRetry' -Operation (New-TestOperation) -ErrorAction SilentlyContinue
        $script:server.Requests.Count | Should -Be 1
    }
}
