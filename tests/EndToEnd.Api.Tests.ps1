# End to end: tests/Fixtures/e2e-api.json -> Import-OpenApiDocument -> New-OpenApiModule -> Import-Module
# (with the real tcs.openapi) -> Set-E2EContext against tests/Helpers/TestHttpServer.ps1 -> the generated
# commands. Assertions are on the raw requests the server recorded and on the command output.

BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $RepoRoot = Split-Path -Path $PSScriptRoot -Parent
    Import-Module -Name (Join-Path -Path $RepoRoot -ChildPath 'modules/tcs.openapi/tcs.openapi.psd1') -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath 'Helpers/TestHttpServer.ps1')
    . (Join-Path -Path $PSScriptRoot -ChildPath 'Helpers/EndToEnd.ps1')

    $script:server = Start-TestHttpServer -Handler {
        param($Request)
        $key = "$($Request.Method) $($Request.Path)"
        if ($key -eq 'GET /items') {
            if ($Request.RawUrl -match 'page=2') {
                return @{ Body = '{"value":[{"id":"c","name":"C"}]}'; ContentType = 'application/json' }
            }
            return @{ Body = '{"value":[{"id":"a","name":"A","category":{"id":1}},{"id":"b","name":"B"}],"nextLink":"{{BaseUri}}/items?page=2"}'; ContentType = 'application/json' }
        }
        if ($key -eq 'GET /events') {
            if ($Request.RawUrl -match 'p=2') {
                return @{ Body = '[{"id":3,"kind":"c"}]'; ContentType = 'application/json' }
            }
            return @{ Body = '[{"id":1,"kind":"a"},{"id":2,"kind":"b"}]'; ContentType = 'application/json'; Headers = @{ Link = '<{{BaseUri}}/events?p=2>; rel="next"' } }
        }
        if ($key -eq 'POST /items') {
            return @{ StatusCode = 201; Body = $Request.Body; ContentType = 'application/json' }
        }
        if ($key -eq 'GET /items/missing') {
            return @{ StatusCode = 404; Body = '{"type":"about:blank","title":"Not Found","status":404,"detail":"There is no item missing."}'; ContentType = 'application/problem+json' }
        }
        if ($Request.Method -eq 'GET' -and $Request.Path -like '/items/*') {
            $id = $Request.Path.Substring(7)
            return @{ Body = ('{"id":"' + $id + '","name":"Item ' + $id + '"}'); ContentType = 'application/json' }
        }
        if ($key -eq 'POST /token') {
            return @{ Body = '{"access_token":"token-123","expires_in":3600,"token_type":"Bearer"}'; ContentType = 'application/json' }
        }
        if ($key -eq 'POST /uploads') {
            return @{ StatusCode = 201; Body = '{"id":"u1","size":5}'; ContentType = 'application/json' }
        }
        if ($Request.Method -eq 'GET' -and $Request.Path -like '/blobs/*') {
            return @{ Body = [byte[]](1, 2, 3, 250); ContentType = 'application/octet-stream' }
        }
        if ($key -eq 'GET /limited') {
            return @{ Body = '{"ok":true}'; ContentType = 'application/json' }
        }
        if ($key -eq 'GET /legacy') {
            return @{ Body = 'old'; ContentType = 'text/plain' }
        }
        return @{ StatusCode = 204 }
    }

    $script:outputRoot = Join-Path -Path $TestDrive -ChildPath 'generated'
    $script:generation = New-EndToEndModule -Fixture 'e2e-api.json' -ModuleName 'E2E' -NounPrefix 'E2E' -OutputPath $script:outputRoot
    Import-Module -Name $script:generation.ManifestPath -Force

    $script:secret = {
        param([string]$Text)
        (New-Object -TypeName System.Net.NetworkCredential -ArgumentList '', $Text).SecurePassword
    }
    $script:connect = {
        Set-E2EContext -BaseUri $script:server.BaseUri -BearerToken (& $script:secret 'bearer-1') -ApiKey (& $script:secret 'key-1') -Credential (New-Object System.Management.Automation.PSCredential -ArgumentList 'user', (& $script:secret 'pass')) -MaxRetries 2
    }
    & $script:connect
}

AfterAll {
    $script:server.Stop()
    Remove-Module -Name E2E -Force -ErrorAction SilentlyContinue
    Remove-Module -Name tcs.openapi -Force -ErrorAction SilentlyContinue
}

Describe 'End to end: generated E2E module against a live test server' {
    BeforeEach {
        $script:server.Requests.Clear()
    }

    Context 'generation and import' {
        It 'generates the expected commands without errors' {
            $names = @($script:generation.Functions.Name)
            foreach ($expected in @('Get-E2EItem', 'Get-E2EItemByItemId', 'New-E2EItem', 'Remove-E2EItem', 'Get-E2EEvent', 'Submit-E2EForm', 'New-E2EUploadFile', 'Get-E2EBlob', 'Set-E2EBlob', 'Get-E2ELimited', 'Get-E2ELegacy', 'Set-E2EContext', 'Get-E2EContext', 'Remove-E2EContext')) {
                $names | Should -Contain $expected
            }
            @($script:generation.Findings | Where-Object -FilterScript { $_.Severity -eq 'Error' }) | Should -BeNullOrEmpty
            @($script:generation.Skipped) | Should -BeNullOrEmpty
        }

        It 'uses the real tcs.openapi from the repository' {
            (Get-Module -Name tcs.openapi).ModuleBase | Should -Be (Join-Path -Path $RepoRoot -ChildPath 'modules/tcs.openapi')
        }

        It 'loads operations.json as Tcs.OpenApi.OperationMetadata objects keyed by operationId' {
            $operation = & (Get-Module -Name E2E) { $script:TcsOpenApiOperations['putBlob'] }
            $operation | Should -BeOfType [System.Management.Automation.PSCustomObject]
            $operation.PSObject.TypeNames[0] | Should -Be 'Tcs.OpenApi.OperationMetadata'
            $operation.Service | Should -Be 'E2E'
            $operation.SecuritySchemes.oauth.Flows.clientCredentials.TokenUrl | Should -Be 'https://e2e.example.com/token'
            @($operation.Security)[0].oauth | Should -Be @('blobs:write')
        }

        It 'exports exactly the functions in the manifest' {
            $manifest = Import-PowerShellDataFile -Path $script:generation.ManifestPath
            @((Get-Module -Name E2E).ExportedFunctions.Keys | Sort-Object) | Should -Be @($manifest.FunctionsToExport | Sort-Object)
        }

        It 'shows the connection with every secret masked' {
            $view = Get-E2EContext
            $view.Service | Should -Be 'E2E'
            $view.BaseUri | Should -Be $script:server.BaseUri
            $view.ApiKey | Should -Be '********'
            $view.BearerToken | Should -Be '********'
            $view.Credential | Should -Be 'user / ********'
            ($view | ConvertTo-Json -Depth 5) | Should -Not -Match 'key-1|bearer-1|pass"'
        }
    }

    Context 'authentication' {
        It 'sends the bearer token for the document default security' {
            Get-E2EItem | Out-Null
            (Get-EndToEndRequest -Server $script:server -Path '/items')[0].Headers['Authorization'] | Should -Be 'Bearer bearer-1'
        }

        It 'sends an api key in a header' {
            New-E2EItem -Name 'n' -Confirm:$false | Out-Null
            $request = @(Get-EndToEndRequest -Server $script:server -Method POST -Path '/items')[0]
            $request.Headers['X-API-Key'] | Should -Be 'key-1'
            $request.Headers['Authorization'] | Should -BeNullOrEmpty
        }

        It 'sends an api key in the query' {
            Get-E2EEvent -Strict $true | Out-Null
            Get-EndToEndQueryPair -Request (Get-EndToEndRequest -Server $script:server -Path '/events')[0] | Should -Contain 'api_key=key-1'
        }

        It 'sends an api key in a cookie' {
            New-E2EUploadFile -Body @{ description = 'd' } -Confirm:$false | Out-Null
            (Get-EndToEndRequest -Server $script:server -Path '/uploads')[0].Headers['Cookie'] | Should -Be 'sid=key-1'
        }

        It 'sends basic credentials' {
            Submit-E2EForm -Body @{ name = 'x' } -Confirm:$false
            (Get-EndToEndRequest -Server $script:server -Path '/forms')[0].Headers['Authorization'] | Should -Be ('Basic ' + [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes('user:pass')))
        }

        It 'sends no credentials for security: []' {
            Get-E2EItemByItemId -ItemId 'x1' | Out-Null
            $request = (Get-EndToEndRequest -Server $script:server -Path '/items/x1')[0]
            $request.Headers['Authorization'] | Should -BeNullOrEmpty
            $request.Headers['X-API-Key'] | Should -BeNullOrEmpty
            $request.Headers['Cookie'] | Should -BeNullOrEmpty
        }

        It 'gets an OAuth2 client-credentials token once and reuses it' {
            try {
                Set-E2EContext -BaseUri $script:server.BaseUri -ClientId 'client-1' -ClientSecret (& $script:secret 'client-secret') -TokenUri "$($script:server.BaseUri)/token"
                Set-E2EBlob -BlobId 'b1' -Body ([byte[]](9, 8, 7)) -Confirm:$false
                Set-E2EBlob -BlobId 'b2' -Body ([byte[]](6)) -Confirm:$false
                $tokenRequests = @(Get-EndToEndRequest -Server $script:server -Method POST -Path '/token')
                $tokenRequests.Count | Should -Be 1
                $tokenRequests[0].ContentType | Should -Match 'application/x-www-form-urlencoded'
                $tokenRequests[0].Body | Should -Match 'grant_type=client_credentials'
                $tokenRequests[0].Body | Should -Match 'scope=blobs%3Awrite'
                $puts = @(Get-EndToEndRequest -Server $script:server -Method PUT)
                $puts.Count | Should -Be 2
                $puts | ForEach-Object -Process { $_.Headers['Authorization'] | Should -Be 'Bearer token-123' }
            }
            finally {
                & $script:connect
            }
        }
    }

    Context 'parameter serialisation' {
        It 'serialises query arrays (form, explode false, pipeDelimited), deepObject, switches, dates and headers' {
            Get-E2EItem -Tags 'a', 'b' -Ids 1, 2 -Codes 'x', 'y' -Filter @{ color = 'red' } -IncludeArchived -Since ([datetime]::new(2020, 1, 2, 3, 4, 5, [System.DateTimeKind]::Utc)) -XRequestId 'rid-1' | Out-Null
            $request = (Get-EndToEndRequest -Server $script:server -Path '/items')[0]
            $pairs = Get-EndToEndQueryPair -Request $request
            $pairs | Should -Contain 'tags=a'
            $pairs | Should -Contain 'tags=b'
            $pairs | Should -Contain 'ids=1,2'
            $pairs | Should -Contain 'codes=x%7Cy'
            $pairs | Should -Contain 'filter%5Bcolor%5D=red'
            $pairs | Should -Contain 'includeArchived=true'
            $pairs | Should -Contain 'since=2020-01-02T03%3A04%3A05.0000000Z'
            $pairs.Count | Should -Be 7
            $request.Headers['X-Request-Id'] | Should -Be 'rid-1'
        }

        It 'sends an explicit false switch and a required [bool]' {
            Get-E2EItem -IncludeArchived:$false | Out-Null
            Get-E2EEvent -Strict $false | Out-Null
            Get-EndToEndQueryPair -Request (Get-EndToEndRequest -Server $script:server -Path '/items')[0] | Should -Be @('includeArchived=false')
            Get-EndToEndQueryPair -Request (Get-EndToEndRequest -Server $script:server -Path '/events')[0] | Should -Contain 'strict=false'
        }

        It 'sends only the parameters that were given' {
            Get-E2EItem | Out-Null
            (Get-EndToEndRequest -Server $script:server -Path '/items')[0].RawUrl | Should -Be '/items'
        }

        It 'escapes path values' {
            Get-E2EItemByItemId -ItemId 'a b/c' | Out-Null
            $script:server.Requests[0].RawUrl | Should -Be '/items/a%20b%2Fc'
        }
    }

    Context 'request bodies' {
        It 'sends flattened JSON body parameters, including a nested (stub) schema as a hashtable' {
            $created = New-E2EItem -Name 'n' -Price 1.5 -Active -Category @{ id = 2; parent = @{ id = 1 } } -Labels 'l1' -Confirm:$false
            $request = (Get-EndToEndRequest -Server $script:server -Method POST -Path '/items')[0]
            $request.ContentType | Should -Be 'application/json; charset=utf-8'
            $body = $request.Body | ConvertFrom-Json
            $body.name | Should -Be 'n'
            $body.price | Should -Be 1.5
            $body.active | Should -BeExactly $true
            $body.category.id | Should -Be 2
            $body.category.parent.id | Should -Be 1
            @($body.labels) | Should -Be @('l1')
            @($body.PSObject.Properties.Name | Sort-Object) | Should -Be @('active', 'category', 'labels', 'name', 'price')
            $created.PSObject.TypeNames[0] | Should -Be 'E2E.Item'
        }

        It 'sends -Body as a whole' {
            New-E2EItem -Body ([pscustomobject]@{ name = 'whole'; labels = @('a', 'b') }) -Confirm:$false | Out-Null
            $body = (Get-EndToEndRequest -Server $script:server -Method POST -Path '/items')[0].Body | ConvertFrom-Json
            $body.name | Should -Be 'whole'
            @($body.labels) | Should -Be @('a', 'b')
        }

        It 'sends a form body' {
            Submit-E2EForm -Body @{ name = 'a b'; count = 2 } -Confirm:$false
            $request = (Get-EndToEndRequest -Server $script:server -Path '/forms')[0]
            $request.ContentType | Should -Be 'application/x-www-form-urlencoded'
            @($request.Body.Split('&') | Sort-Object) | Should -Be @('count=2', 'name=a%20b')
        }

        It 'sends a multipart body with a file part' {
            $file = Join-Path -Path $TestDrive -ChildPath 'upload.txt'
            [System.IO.File]::WriteAllText($file, 'hello')
            $result = New-E2EUploadFile -Body @{ description = 'a file'; file = (Get-Item -LiteralPath $file) } -Confirm:$false
            $request = (Get-EndToEndRequest -Server $script:server -Path '/uploads')[0]
            $request.ContentType | Should -Match '^multipart/form-data; boundary='
            $request.Body | Should -Match 'name="?file"?; filename="?upload\.txt"?'
            $request.Body | Should -Match "(?s)upload\.txt.*\r\n\r\nhello\r\n"
            $request.Body | Should -Match 'name="?description"?'
            $request.Body | Should -Match "\r\n\r\na file\r\n"
            $result.PSObject.TypeNames[0] | Should -Be 'E2E.Upload'
        }

        It 'sends a binary body byte for byte' {
            Set-E2EBlob -BlobId 'b1' -Body ([byte[]](0, 9, 255)) -Confirm:$false
            $request = @(Get-EndToEndRequest -Server $script:server -Method PUT)[0]
            $request.ContentType | Should -Be 'application/octet-stream'
            $request.BodyBytes | Should -Be @(0, 9, 255)
        }
    }

    Context 'responses and paging' {
        It 'returns the items of one page, typed with the item schema' {
            $items = @(Get-E2EItem)
            $items.id | Should -Be @('a', 'b')
            $items | ForEach-Object -Process { $_.PSObject.TypeNames[0] | Should -Be 'E2E.Item' }
            $script:server.Requests.Count | Should -Be 1
        }

        It 'follows nextLink with -All' {
            $items = @(Get-E2EItem -All)
            $items.id | Should -Be @('a', 'b', 'c')
            $items[2].PSObject.TypeNames[0] | Should -Be 'E2E.Item'
            @($script:server.Requests.ToArray().RawUrl) | Should -Be @('/items', '/items?page=2')
        }

        It 'streams -All: stopping the pipeline early fetches no more pages' {
            $first = Get-E2EItem -All | Select-Object -First 1
            $first.id | Should -Be 'a'
            $script:server.Requests.Count | Should -Be 1
        }

        It 'follows a Link rel="next" header with -All' {
            $events = @(Get-E2EEvent -Strict $true -All)
            $events.id | Should -Be @(1, 2, 3)
            $events | ForEach-Object -Process { $_.PSObject.TypeNames[0] | Should -Be 'E2E.Event' }
            $script:server.Requests.Count | Should -Be 2
        }

        It 'returns the raw response with -Raw' {
            $raw = Get-E2EItemByItemId -ItemId 'r1' -Raw
            $raw.StatusCode | Should -Be 200
            $raw.Content | Should -Match '"id":"r1"'
            $raw.PSObject.TypeNames[0] | Should -Be 'Tcs.OpenApi.RawResponse'
        }

        It 'returns a binary download as one byte array' {
            $bytes = Get-E2EBlob -BlobId 'b1'
            , $bytes | Should -BeOfType [byte[]]
            $bytes | Should -Be ([byte[]](1, 2, 3, 250))
            $script:server.Requests[0].Headers['Accept'] | Should -Be 'application/octet-stream'
        }

        It 'saves a download with -OutFile and returns the file' {
            $path = Join-Path -Path $TestDrive -ChildPath 'blob.bin'
            $file = Get-E2EBlob -BlobId 'b1' -OutFile $path
            $file | Should -BeOfType [System.IO.FileInfo]
            $file.FullName | Should -Be $path
            [System.IO.File]::ReadAllBytes($path) | Should -Be @(1, 2, 3, 250)
        }

        It 'returns text responses as a string' {
            Get-E2ELegacy -WarningAction SilentlyContinue | Should -Be 'old'
        }
    }

    Context 'retry' {
        It 'retries a 429 after the Retry-After delay' {
            $script:server.Enqueue(@{ StatusCode = 429; Headers = @{ 'Retry-After' = '1' }; Body = 'slow down'; ContentType = 'text/plain' })
            $watch = [System.Diagnostics.Stopwatch]::StartNew()
            $result = Get-E2ELimited
            $watch.Stop()
            $result.ok | Should -BeTrue
            $script:server.Requests.Count | Should -Be 2
            $watch.Elapsed.TotalMilliseconds | Should -BeGreaterThan 900
        }
    }

    Context 'errors' {
        It 'writes a problem+json 404 as an ErrorRecord with the documented id, message and target' {
            $errors = $null
            $output = Get-E2EItemByItemId -ItemId 'missing' -ErrorAction SilentlyContinue -ErrorVariable errors
            $output | Should -BeNullOrEmpty
            $errors.Count | Should -Be 1
            $errors[0].FullyQualifiedErrorId | Should -Be 'OpenApi.E2E.404,Get-E2EItemByItemId'
            $errors[0].CategoryInfo.Category | Should -Be 'ObjectNotFound'
            $errors[0].Exception.Message | Should -Match 'There is no item missing\.'
            $errors[0].TargetObject.StatusCode | Should -Be 404
            $errors[0].TargetObject.OperationId | Should -Be 'getItem'
            $errors[0].TargetObject.Method | Should -Be 'GET'
            $errors[0].TargetObject.Body.title | Should -Be 'Not Found'
        }

        It '-ErrorAction SilentlyContinue suppresses the error' {
            $all = Get-E2EItemByItemId -ItemId 'missing' -ErrorAction SilentlyContinue 2>&1
            $all | Should -BeNullOrEmpty
        }

        It '-ErrorAction Stop throws' {
            { Get-E2EItemByItemId -ItemId 'missing' -ErrorAction Stop } | Should -Throw -ErrorId 'OpenApi.E2E.404,Get-E2EItemByItemId'
        }

        It 'continues the pipeline after an error' {
            $errors = $null
            $items = @('one', 'missing', 'two' | ForEach-Object -Process { [pscustomobject]@{ ItemId = $_ } } | Get-E2EItemByItemId -ErrorAction SilentlyContinue -ErrorVariable errors)
            $items.id | Should -Be @('one', 'two')
            $errors.Count | Should -Be 1
            $script:server.Requests.Count | Should -Be 3
        }

        It 'reports a missing connection without sending anything' {
            try {
                Remove-E2EContext -Confirm:$false
                $errors = $null
                Get-E2EItem -ErrorAction SilentlyContinue -ErrorVariable errors
                $errors[0].FullyQualifiedErrorId | Should -BeLike 'OpenApi.E2E.NoContext*'
                $script:server.Requests.Count | Should -Be 0
            }
            finally {
                & $script:connect
            }
        }
    }

    Context 'ShouldProcess and deprecation' {
        It '-WhatIf sends nothing' {
            Remove-E2EItem -ItemId 'z' -WhatIf
            New-E2EItem -Name 'n' -WhatIf
            Set-E2EBlob -BlobId 'b' -Body ([byte[]](1)) -WhatIf
            $script:server.Requests.Count | Should -Be 0
        }

        It 'DELETE asks for confirmation (ConfirmImpact High) and sends with -Confirm:$false' {
            (Get-Command -Name Remove-E2EItem).ScriptBlock.Attributes.Where({ $_ -is [System.Management.Automation.CmdletBindingAttribute] })[0].ConfirmImpact | Should -Be 'High'
            Remove-E2EItem -ItemId 'z' -Confirm:$false
            (Get-EndToEndRequest -Server $script:server -Method DELETE)[0].RawUrl | Should -Be '/items/z'
        }

        It 'warns once per session for a deprecated operation' {
            $first = $null
            $second = $null
            Get-E2ELegacy -WarningVariable first -WarningAction SilentlyContinue | Out-Null
            Get-E2ELegacy -WarningVariable second -WarningAction SilentlyContinue | Out-Null
            # An earlier test may already have called it; either way there is at most one warning
            (@($first).Count + @($second).Count) | Should -BeLessOrEqual 1
            @($second).Count | Should -Be 0
        }
    }

    Context 'persisted connection' {
        It 'saves the connection with -Persist and loads it lazily after the in-memory context is gone' {
            try {
                Set-E2EContext -BaseUri $script:server.BaseUri -ApiKey (& $script:secret 'saved-key') -Persist
                Remove-E2EContext -Confirm:$false
                New-E2EItem -Name 'n' -Confirm:$false | Out-Null
                (Get-EndToEndRequest -Server $script:server -Method POST -Path '/items')[0].Headers['X-API-Key'] | Should -Be 'saved-key'
                (Get-E2EContext).Persisted | Should -BeTrue
                $saved = Get-ChildItem -LiteralPath $env:TCS_CONFIG_ROOT -Recurse -File | ForEach-Object -Process { [System.IO.File]::ReadAllText($_.FullName) }
                ($saved -join "`n") | Should -Not -Match 'saved-key'
            }
            finally {
                Remove-E2EContext -Persisted -Confirm:$false
                & $script:connect
            }
        }
    }

    Context 'verbose and debug output' {
        It 'writes the request line to Verbose and redacts secrets in Debug' {
            $records = @(New-E2EItem -Body @{ name = 'n'; password = 'hunter2' } -Confirm:$false -Verbose -Debug 4>&1 5>&1 |
                    Where-Object -FilterScript { $_ -is [System.Management.Automation.VerboseRecord] -or $_ -is [System.Management.Automation.DebugRecord] })
            $text = ($records | ForEach-Object -Process { $_.Message }) -join "`n"
            @($records | Where-Object -FilterScript { $_ -is [System.Management.Automation.VerboseRecord] -and $_.Message -match 'POST .*/items' }).Count | Should -BeGreaterThan 0
            $text | Should -Not -Match 'key-1'
            $text | Should -Not -Match 'hunter2'
            $text | Should -Match '\*{8}'
        }
    }

    Context 'Overrides.ps1' {
        It 'a function defined in Overrides.ps1 replaces the generated one' {
            $overrides = Join-Path -Path $script:generation.Path -ChildPath 'Overrides.ps1'
            Add-Content -LiteralPath $overrides -Value @'

function Get-E2ELimited {
    [CmdletBinding()]
    param()
    'overridden'
}
'@
            Import-Module -Name $script:generation.ManifestPath -Force
            Get-E2ELimited | Should -Be 'overridden'
            $script:server.Requests.Count | Should -Be 0
            (Get-Command -Name Get-E2ELimited).Module.Name | Should -Be 'E2E'
            # The other commands still work
            (Get-E2EItemByItemId -ItemId 'k').id | Should -Be 'k'
        }

        It 'regenerating with -Force keeps Overrides.ps1' {
            $overrides = Join-Path -Path $script:generation.Path -ChildPath 'Overrides.ps1'
            $before = [System.IO.File]::ReadAllText($overrides)
            $regenerated = New-OpenApiModule -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Fixtures/e2e-api.json') -ModuleName 'E2E' -NounPrefix 'E2E' -OutputPath $script:outputRoot -Force
            ($regenerated.Files | Where-Object -FilterScript { $_.RelativePath -eq 'Overrides.ps1' }).Action | Should -Be 'Preserved'
            [System.IO.File]::ReadAllText($overrides) | Should -BeExactly $before
        }
    }
}
