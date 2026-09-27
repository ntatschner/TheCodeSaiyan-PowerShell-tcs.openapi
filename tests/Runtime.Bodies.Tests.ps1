BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $repoRoot = Split-Path -Path $PSScriptRoot -Parent
    Import-Module -Name (Join-Path -Path $repoRoot -ChildPath 'modules/tcs.openapi/tcs.openapi.psd1') -Force
    # Windows PowerShell 5.1 does not load System.Net.Http by default
    Add-Type -AssemblyName 'System.Net.Http'
    . (Join-Path -Path $PSScriptRoot -ChildPath 'Helpers/TestHttpServer.ps1')
    $script:server = Start-TestHttpServer -Handler { param($Request) @{ StatusCode = 201; Body = @{ created = $true } } }
    Set-OpenApiContext -Service 'Body' -BaseUri $script:server.BaseUri

    function New-TestOperation {
        param([string[]]$ContentTypes = @('application/json'), [string]$Method = 'POST')
        return @{
            OperationId         = 'send'
            Method              = $Method
            Path                = '/upload'
            Security            = @()
            RequestContentTypes = $ContentTypes
        }
    }

    function Get-MultipartPart {
        # Splits a recorded multipart body into parts: { Headers (text), Bytes }
        param($Request)
        $contentType = $Request.ContentType
        $boundary = ([regex]::Match($contentType, 'boundary="?([^";]+)"?')).Groups[1].Value
        $latin1 = [System.Text.Encoding]::GetEncoding(28591)
        $text = $latin1.GetString($Request.BodyBytes)
        $sections = $text -split [regex]::Escape("--$boundary")
        foreach ($section in $sections) {
            if ($section -eq '' -or $section.StartsWith('--')) {
                continue
            }
            $split = $section.IndexOf("`r`n`r`n")
            $headerText = $section.Substring(2, $split - 2)
            $bodyText = $section.Substring($split + 4)
            $bodyText = $bodyText.Substring(0, $bodyText.Length - 2)
            [pscustomobject]@{
                Headers = $headerText
                Bytes   = $latin1.GetBytes($bodyText)
                Text    = [System.Text.Encoding]::UTF8.GetString($latin1.GetBytes($bodyText))
            }
        }
    }
}

AfterAll {
    $script:server.Stop()
    Remove-Module -Name tcs.openapi -Force -ErrorAction SilentlyContinue
}

Describe 'Invoke-OpenApiRequest request bodies (end to end)' {
    BeforeEach {
        $script:server.Requests.Clear()
    }

    It 'sends JSON with charset utf-8, keeping explicit nulls, single-item arrays and ISO dates' {
        $body = [ordered]@{
            name  = "Caf$([char]0x00E9)"
            note  = $null
            tags  = @('one')
            when  = (New-Object System.DateTime -ArgumentList 2024, 2, 3, 4, 5, 6, ([System.DateTimeKind]::Utc))
            inner = [ordered]@{ ok = $true }
        }
        $result = Invoke-OpenApiRequest -Service 'Body' -Operation (New-TestOperation) -Body $body
        $result.created | Should -BeTrue
        $request = $script:server.Requests[0]
        $request.ContentType | Should -Be 'application/json; charset=utf-8'
        $request.Body | Should -Be "{`"name`":`"Caf$([char]0x00E9)`",`"note`":null,`"tags`":[`"one`"],`"when`":`"2024-02-03T04:05:06.0000000Z`",`"inner`":{`"ok`":true}}"
        $request.BodyBytes[0..3] | Should -Be ([byte[]][char[]]'{"na')
    }

    It 'sends an explicit $null body as JSON null' {
        $null = Invoke-OpenApiRequest -Service 'Body' -Operation (New-TestOperation) -Body $null
        $script:server.Requests[0].Body | Should -Be 'null'
    }

    It 'sends a string body as it is' {
        $null = Invoke-OpenApiRequest -Service 'Body' -Operation (New-TestOperation) -Body '{"raw":1}'
        $script:server.Requests[0].Body | Should -Be '{"raw":1}'
    }

    It 'sends no body when -Body is not given' {
        $null = Invoke-OpenApiRequest -Service 'Body' -Operation (New-TestOperation)
        $script:server.Requests[0].BodyBytes.Length | Should -Be 0
    }

    It 'sends a JSON array body' {
        $null = Invoke-OpenApiRequest -Service 'Body' -Operation (New-TestOperation) -Body @(@{ a = 1 })
        $script:server.Requests[0].Body | Should -Be '[{"a":1}]'
    }

    It 'sends application/x-www-form-urlencoded pairs' {
        $body = [ordered]@{ name = 'a b&c'; ids = @(1, 2); on = $true }
        $null = Invoke-OpenApiRequest -Service 'Body' -Operation (New-TestOperation -ContentTypes 'application/x-www-form-urlencoded') -Body $body
        $script:server.Requests[0].ContentType | Should -Be 'application/x-www-form-urlencoded'
        $script:server.Requests[0].Body | Should -Be 'name=a%20b%26c&ids=1&ids=2&on=true'
    }

    It 'sends multipart/form-data with text, JSON and file parts from FileInfo, byte[] and streams' {
        $file = Join-Path -Path $TestDrive -ChildPath 'photo.bin'
        $fileBytes = [byte[]](0, 1, 2, 255, 13, 10, 45, 45, 65)
        [System.IO.File]::WriteAllBytes($file, $fileBytes)
        $stream = New-Object System.IO.MemoryStream -ArgumentList (, [byte[]](7, 8, 9))
        $body = [ordered]@{
            title  = 'Holiday'
            meta   = [ordered]@{ size = 2 }
            photo  = Get-Item -LiteralPath $file
            thumb  = [byte[]](4, 5, 6)
            extra  = $stream
            labels = @('x', 'y')
        }
        $null = Invoke-OpenApiRequest -Service 'Body' -Operation (New-TestOperation -ContentTypes 'multipart/form-data') -Body $body
        $request = $script:server.Requests[0]
        $request.ContentType | Should -Match '^multipart/form-data; boundary="?[^"]+"?$'
        $parts = @(Get-MultipartPart -Request $request)
        $parts.Count | Should -Be 7

        $parts[0].Headers | Should -Match 'Content-Disposition: form-data; name="?title"?'
        $parts[0].Headers | Should -Match 'Content-Type: text/plain; charset=utf-8'
        $parts[0].Text | Should -Be 'Holiday'

        $parts[1].Headers | Should -Match 'Content-Type: application/json'
        $parts[1].Text | Should -Be '{"size":2}'

        $parts[2].Headers | Should -Match 'name="?photo"?; filename="?photo.bin"?'
        $parts[2].Headers | Should -Match 'Content-Type: application/octet-stream'
        $parts[2].Bytes | Should -Be $fileBytes

        $parts[3].Headers | Should -Match 'name="?thumb"?; filename="?thumb"?'
        $parts[3].Bytes | Should -Be ([byte[]](4, 5, 6))
        $parts[4].Bytes | Should -Be ([byte[]](7, 8, 9))

        $parts[5].Text | Should -Be 'x'
        $parts[6].Text | Should -Be 'y'
        $parts[6].Headers | Should -Match 'name="?labels"?'
        $stream.Dispose()
    }

    It 'sends binary bodies from byte[], streams and files byte for byte' {
        $bytes = [byte[]](0, 128, 255, 10)
        $null = Invoke-OpenApiRequest -Service 'Body' -Operation (New-TestOperation -ContentTypes 'application/octet-stream' -Method 'PUT') -Body $bytes
        $script:server.Requests[0].ContentType | Should -Be 'application/octet-stream'
        $script:server.Requests[0].BodyBytes | Should -Be $bytes

        $stream = New-Object System.IO.MemoryStream -ArgumentList (, $bytes)
        $stream.Position = 2
        $null = Invoke-OpenApiRequest -Service 'Body' -Operation (New-TestOperation -ContentTypes 'application/octet-stream' -Method 'PUT') -Body $stream
        $script:server.Requests[1].BodyBytes | Should -Be $bytes
        $stream.CanRead | Should -BeTrue
        $stream.Dispose()

        $file = Join-Path -Path $TestDrive -ChildPath 'data.bin'
        [System.IO.File]::WriteAllBytes($file, $bytes)
        $null = Invoke-OpenApiRequest -Service 'Body' -Operation (New-TestOperation -ContentTypes 'image/png' -Method 'PUT') -Body (Get-Item -LiteralPath $file)
        $script:server.Requests[2].ContentType | Should -Be 'image/png'
        $script:server.Requests[2].BodyBytes | Should -Be $bytes
    }

    It 'sends text bodies with charset utf-8' {
        $null = Invoke-OpenApiRequest -Service 'Body' -Operation (New-TestOperation -ContentTypes 'text/plain') -Body "line $([char]0x00FC)"
        $script:server.Requests[0].ContentType | Should -Be 'text/plain; charset=utf-8'
        $script:server.Requests[0].Body | Should -Be "line $([char]0x00FC)"
    }

    It 'uses -ContentType over the operation content types' {
        $null = Invoke-OpenApiRequest -Service 'Body' -Operation (New-TestOperation) -Body 'a=1' -ContentType 'application/x-www-form-urlencoded'
        $script:server.Requests[0].ContentType | Should -Be 'application/x-www-form-urlencoded'
        $script:server.Requests[0].Body | Should -Be 'a=1'
    }

    It 'reports a missing file as an invalid argument' {
        $errors = $null
        $missing = New-Object System.IO.FileInfo -ArgumentList (Join-Path -Path $TestDrive -ChildPath 'missing.bin')
        $null = Invoke-OpenApiRequest -Service 'Body' -Operation (New-TestOperation -ContentTypes 'application/octet-stream') -Body $missing -ErrorAction SilentlyContinue -ErrorVariable errors
        $record = @($errors | Where-Object -FilterScript { $_.FullyQualifiedErrorId -like 'OpenApi.*' })[0]
        $record.FullyQualifiedErrorId | Should -BeLike 'OpenApi.Body.InvalidArgument*'
        $script:server.Requests.Count | Should -Be 0
    }
}
