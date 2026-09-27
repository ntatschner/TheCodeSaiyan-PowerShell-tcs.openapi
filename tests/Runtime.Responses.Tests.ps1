BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $repoRoot = Split-Path -Path $PSScriptRoot -Parent
    Import-Module -Name (Join-Path -Path $repoRoot -ChildPath 'modules/tcs.openapi/tcs.openapi.psd1') -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath 'Helpers/TestHttpServer.ps1')
    $script:payload = [byte[]](0..255 + 0..255)
    $script:server = Start-TestHttpServer -Routes @{
        'GET /file'    = @{ Body = $script:payload; ContentType = 'application/octet-stream'; Headers = @{ 'Content-Disposition' = 'attachment; filename="data.bin"' } }
        'GET /one'     = @{ Body = '{"id":1,"when":"2024-01-01T00:00:00Z","nested":{"a":1}}'; ContentType = 'application/json; charset=utf-8' }
        'GET /many'    = @{ Body = '[{"id":1},{"id":2},3]'; ContentType = 'application/json' }
        'GET /single'  = @{ Body = '[{"id":1}]'; ContentType = 'application/json' }
        'DELETE /one'  = @{ StatusCode = 204 }
        'GET /text'    = @{ Body = 'plain text'; ContentType = 'text/plain; charset=utf-8' }
        'GET /secret'  = @{ Body = '{"access_token":"abc123","name":"x"}'; ContentType = 'application/json'; Headers = @{ 'Set-Cookie' = 'sid=zzz' } }
        'POST /secret' = @{ Body = '{"ok":true}'; ContentType = 'application/json' }
    }
    Set-OpenApiContext -Service 'Resp' -BaseUri $script:server.BaseUri -ApiKey (ConvertTo-SecureString -String 'KEY-999' -AsPlainText -Force) -MaxRetries 0

    function New-TestOperation {
        param([string]$Path, [string]$Method = 'GET', [string]$TypeName, [switch]$Binary, [switch]$Deprecated, [string]$Id = 'op')
        return @{
            OperationId      = $Id
            Method           = $Method
            Path             = $Path
            Deprecated       = [bool]$Deprecated
            Security         = @(@{ key = @() })
            SecuritySchemes  = @{ key = @{ Type = 'apiKey'; In = 'query'; ParameterName = 'api_key' } }
            BinaryResponse   = [bool]$Binary
            ResponseTypeName = $TypeName
        }
    }
}

AfterAll {
    $script:server.Stop()
    Remove-Module -Name tcs.openapi -Force -ErrorAction SilentlyContinue
}

Describe 'Invoke-OpenApiRequest responses (end to end)' {
    It 'streams a download to -OutFile and returns the FileInfo' {
        $path = Join-Path -Path $TestDrive -ChildPath 'download.bin'
        $file = Invoke-OpenApiRequest -Service 'Resp' -Operation (New-TestOperation -Path '/file' -Binary) -OutFile $path
        $file | Should -BeOfType ([System.IO.FileInfo])
        $file.FullName | Should -Be (Get-Item -LiteralPath $path).FullName
        [System.IO.File]::ReadAllBytes($path) | Should -Be $script:payload
    }

    It 'saves a JSON response to -OutFile as it was sent' {
        $path = Join-Path -Path $TestDrive -ChildPath 'one.json'
        $null = Invoke-OpenApiRequest -Service 'Resp' -Operation (New-TestOperation -Path '/one') -OutFile $path
        [System.IO.File]::ReadAllText($path) | Should -Be '{"id":1,"when":"2024-01-01T00:00:00Z","nested":{"a":1}}'
    }

    It 'returns a binary response as one byte array without -OutFile' {
        $bytes = Invoke-OpenApiRequest -Service 'Resp' -Operation (New-TestOperation -Path '/file' -Binary)
        , $bytes | Should -BeOfType ([byte[]])
        $bytes.Length | Should -Be 512
    }

    It 'converts JSON and adds the response PSTypeName' {
        $result = Invoke-OpenApiRequest -Service 'Resp' -Operation (New-TestOperation -Path '/one' -TypeName 'Resp.Thing')
        $result.id | Should -Be 1
        $result.nested.a | Should -Be 1
        $result.PSObject.TypeNames[0] | Should -Be 'Resp.Thing'
    }

    It 'writes array items one by one, each with the PSTypeName' {
        $items = @(Invoke-OpenApiRequest -Service 'Resp' -Operation (New-TestOperation -Path '/many' -TypeName 'Resp.Item'))
        $items.Count | Should -Be 3
        $items[0].PSObject.TypeNames[0] | Should -Be 'Resp.Item'
        $items[1].PSObject.TypeNames[0] | Should -Be 'Resp.Item'
        $items[2] | Should -Be 3
        $single = @(Invoke-OpenApiRequest -Service 'Resp' -Operation (New-TestOperation -Path '/single'))
        $single.Count | Should -Be 1
    }

    It 'returns nothing for 204' {
        $result = Invoke-OpenApiRequest -Service 'Resp' -Operation (New-TestOperation -Path '/one' -Method 'DELETE')
        $result | Should -BeNullOrEmpty
    }

    It 'returns text for text responses' {
        Invoke-OpenApiRequest -Service 'Resp' -Operation (New-TestOperation -Path '/text') | Should -Be 'plain text'
    }

    It 'returns StatusCode, Headers and Content with -Raw' {
        $raw = Invoke-OpenApiRequest -Service 'Resp' -Operation (New-TestOperation -Path '/one') -Raw
        $raw.PSObject.TypeNames[0] | Should -Be 'Tcs.OpenApi.RawResponse'
        $raw.StatusCode | Should -Be 200
        $raw.Headers['Content-Type'] | Should -Be 'application/json; charset=utf-8'
        $raw.Content | Should -Be '{"id":1,"when":"2024-01-01T00:00:00Z","nested":{"a":1}}'
        $rawBinary = Invoke-OpenApiRequest -Service 'Resp' -Operation (New-TestOperation -Path '/file' -Binary) -Raw
        , $rawBinary.Content | Should -BeOfType ([byte[]])
    }

    It 'writes a deprecation warning once per operation per session' {
        $first = $null
        $second = $null
        $null = Invoke-OpenApiRequest -Service 'Resp' -Operation (New-TestOperation -Path '/one' -Deprecated -Id 'oldOp') -WarningVariable first -WarningAction SilentlyContinue
        $null = Invoke-OpenApiRequest -Service 'Resp' -Operation (New-TestOperation -Path '/one' -Deprecated -Id 'oldOp') -WarningVariable second -WarningAction SilentlyContinue
        @($first).Count | Should -Be 1
        $first[0].Message | Should -Match "'oldOp'.*deprecated"
        @($second).Count | Should -Be 0
    }

    It 'writes the request line and status to Verbose with the api key redacted' {
        $verbose = @(Invoke-OpenApiRequest -Service 'Resp' -Operation (New-TestOperation -Path '/one') -Verbose 4>&1 | Where-Object -FilterScript { $_ -is [System.Management.Automation.VerboseRecord] })
        $text = ($verbose | ForEach-Object -Process { $_.Message }) -join "`n"
        $text | Should -Match ([regex]::Escape("GET $($script:server.BaseUri)/one?api_key=********"))
        $text | Should -Match '-> 200 OK'
        $text | Should -Not -Match 'KEY-999'
    }

    It 'writes headers and bodies to Debug with secrets redacted' {
        $operation = New-TestOperation -Path '/secret' -Method 'POST'
        $operation['SecuritySchemes'] = @{ key = @{ Type = 'apiKey'; In = 'header'; ParameterName = 'X-Api-Key' } }
        $body = [ordered]@{ user = 'me'; password = 'p4ss'; client_secret = 'cs'; nested = @{ refreshToken = 'rt' } }
        $debug = @(Invoke-OpenApiRequest -Service 'Resp' -Operation $operation -Body $body -CookieParameters @{ session = 'cookie-value' } -Debug 5>&1 | Where-Object -FilterScript { $_ -is [System.Management.Automation.DebugRecord] })
        $text = ($debug | ForEach-Object -Process { $_.Message }) -join "`n"
        $text | Should -Match 'X-Api-Key: \*{8}'
        $text | Should -Match 'Cookie: \*{8}'
        $text | Should -Match '"password":"\*{8}"'
        $text | Should -Match '"client_secret":"\*{8}"'
        $text | Should -Match '"refreshToken":"\*{8}"'
        $text | Should -Match '"user":"me"'
        foreach ($secret in 'KEY-999', 'p4ss', 'cookie-value', '"cs"', '"rt"') {
            $text | Should -Not -Match ([regex]::Escape($secret))
        }
    }

    It 'redacts tokens in response bodies and Set-Cookie headers in Debug output' {
        $debug = @(Invoke-OpenApiRequest -Service 'Resp' -Operation (New-TestOperation -Path '/secret') -Debug 5>&1 | Where-Object -FilterScript { $_ -is [System.Management.Automation.DebugRecord] })
        $text = ($debug | ForEach-Object -Process { $_.Message }) -join "`n"
        $text | Should -Match '"access_token":"\*{8}"'
        $text | Should -Match 'Set-Cookie: \*{8}'
        $text | Should -Not -Match 'abc123'
        $text | Should -Not -Match 'zzz'
    }

    It 'takes Verbose from the calling command passed as -Cmdlet' {
        function Get-TestOne {
            [CmdletBinding()]
            param($Operation)
            Invoke-OpenApiRequest -Service 'Resp' -Operation $Operation -Cmdlet $PSCmdlet
        }
        $operation = New-TestOperation -Path '/one'
        $verbose = @(Get-TestOne -Operation $operation -Verbose 4>&1 | Where-Object -FilterScript { $_ -is [System.Management.Automation.VerboseRecord] })
        $verbose.Count | Should -BeGreaterThan 0
        $quiet = @(Get-TestOne -Operation $operation 4>&1 | Where-Object -FilterScript { $_ -is [System.Management.Automation.VerboseRecord] })
        $quiet.Count | Should -Be 0
    }
}
