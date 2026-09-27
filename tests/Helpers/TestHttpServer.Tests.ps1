BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath 'TestHttpServer.ps1')
}

Describe 'Start-TestHttpServer' {
    BeforeAll {
        $client = New-Object System.Net.Http.HttpClient
        function Get-Text {
            param($Uri, $Method = 'GET', $Body)
            $request = New-Object System.Net.Http.HttpRequestMessage -ArgumentList (New-Object System.Net.Http.HttpMethod -ArgumentList $Method), ([uri]$Uri)
            if ($null -ne $Body) {
                $request.Content = New-Object System.Net.Http.StringContent -ArgumentList $Body
            }
            $request.Headers.Add('X-Test', 'yes')
            $response = $client.SendAsync($request).GetAwaiter().GetResult()
            [pscustomobject]@{
                Status  = [int]$response.StatusCode
                Text    = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
                Headers = $response.Headers
                Type    = $response.Content.Headers.ContentType
            }
        }
    }

    AfterAll {
        $client.Dispose()
    }

    It 'listens on a free loopback port and records requests' {
        $server = Start-TestHttpServer -Handler { param($Request) @{ Body = "you sent $($Request.Body)"; ContentType = 'text/plain' } }
        try {
            $server.BaseUri | Should -Match '^http://(127\.0\.0\.1|localhost):\d+$'
            $result = Get-Text -Uri "$($server.BaseUri)/echo?x=1" -Method 'POST' -Body 'hello'
            $result.Status | Should -Be 200
            $result.Text | Should -Be 'you sent hello'
            $server.Requests.Count | Should -Be 1
            $server.Requests[0].Method | Should -Be 'POST'
            $server.Requests[0].Path | Should -Be '/echo'
            $server.Requests[0].Query | Should -Be '?x=1'
            $server.Requests[0].Headers['X-Test'] | Should -Be 'yes'
            [System.Text.Encoding]::UTF8.GetString($server.Requests[0].BodyBytes) | Should -Be 'hello'
        }
        finally {
            $server.Stop()
        }
    }

    It 'serves queued responses in order before routes' {
        $server = Start-TestHttpServer -Responses @(
            @{ StatusCode = 201; Body = 'first' }
            @{ StatusCode = 202; Body = 'second'; Headers = @{ 'X-Next' = '{{BaseUri}}/next' } }
        ) -Routes @{ 'GET /r' = @{ Body = 'route' } }
        try {
            $first = Get-Text -Uri "$($server.BaseUri)/r"
            $second = Get-Text -Uri "$($server.BaseUri)/r"
            $third = Get-Text -Uri "$($server.BaseUri)/r"
            $first.Status | Should -Be 201
            $first.Text | Should -Be 'first'
            $second.Status | Should -Be 202
            @($second.Headers.GetValues('X-Next'))[0] | Should -Be "$($server.BaseUri)/next"
            $third.Text | Should -Be 'route'
        }
        finally {
            $server.Stop()
        }
    }

    It 'runs script block routes in the server runspace and sends objects as JSON' {
        $server = Start-TestHttpServer -Routes @{
            '/json' = { param($Request) @{ Body = @{ method = $Request.Method; items = @(1, 2) } } }
        }
        try {
            $result = Get-Text -Uri "$($server.BaseUri)/json"
            $result.Type.MediaType | Should -Be 'application/json'
            ($result.Text | ConvertFrom-Json).method | Should -Be 'GET'
        }
        finally {
            $server.Stop()
        }
    }

    It 'returns 404 when nothing is scripted and accepts responses queued later' {
        $server = Start-TestHttpServer
        try {
            (Get-Text -Uri "$($server.BaseUri)/x").Status | Should -Be 404
            $server.Enqueue(@{ StatusCode = 418; Body = [byte[]](1, 2, 3) })
            (Get-Text -Uri "$($server.BaseUri)/x").Status | Should -Be 418
        }
        finally {
            $server.Stop()
        }
    }

    It 'stops listening when stopped' {
        $server = Start-TestHttpServer
        $server.Stop()
        $server.Listener.IsListening | Should -BeFalse
    }
}
