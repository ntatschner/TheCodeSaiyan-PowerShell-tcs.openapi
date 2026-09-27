BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $repoRoot = Split-Path -Path $PSScriptRoot -Parent
    Import-Module -Name (Join-Path -Path $repoRoot -ChildPath 'modules/tcs.openapi/tcs.openapi.psd1') -Force
    # Windows PowerShell 5.1 does not load System.Net.Http by default
    Add-Type -AssemblyName 'System.Net.Http'
    . (Join-Path -Path $PSScriptRoot -ChildPath 'Helpers/TestHttpServer.ps1')
    $script:server = Start-TestHttpServer -Handler { param($Request) @{ StatusCode = 204 } }
    Set-OpenApiContext -Service 'Ser' -BaseUri "$($script:server.BaseUri)/api/v1/"

    $script:operation = @{
        OperationId = 'search'
        Method      = 'GET'
        Path        = '/items/{id}/sub/{parts}'
        Security    = @()
        Parameters  = @(
            @{ Name = 'id'; In = 'path' }
            @{ Name = 'parts'; In = 'path'; Style = 'simple'; Explode = $false }
            @{ Name = 'tags'; In = 'query'; Style = 'form'; Explode = $true }
            @{ Name = 'ids'; In = 'query'; Style = 'form'; Explode = $false }
            @{ Name = 'spaced'; In = 'query'; Style = 'spaceDelimited'; Explode = $false }
            @{ Name = 'piped'; In = 'query'; Style = 'pipeDelimited'; Explode = $false }
            @{ Name = 'filter'; In = 'query'; Style = 'deepObject'; Explode = $true }
            @{ Name = 'raw'; In = 'query'; AllowReserved = $true }
            @{ Name = 'X-Ids'; In = 'header' }
            @{ Name = 'X-Obj'; In = 'header'; Explode = $true }
            @{ Name = 'prefs'; In = 'cookie'; Explode = $false }
        )
    }
}

AfterAll {
    $script:server.Stop()
    Remove-Module -Name tcs.openapi -Force -ErrorAction SilentlyContinue
}

Describe 'Invoke-OpenApiRequest parameter serialisation (end to end)' {
    BeforeEach {
        $script:server.Requests.Clear()
    }

    It 'escapes path values per segment and joins the base URI path' {
        $null = Invoke-OpenApiRequest -Service 'Ser' -Operation $script:operation -PathParameters @{ id = 'a b/c'; parts = @('x', 'y') }
        $script:server.Requests[0].RawUrl | Should -Be '/api/v1/items/a%20b%2Fc/sub/x,y'
    }

    It 'serialises query arrays and objects with their style and explode settings' {
        $query = [ordered]@{
            tags   = @('red', 'green')
            ids    = @(1, 2, 3)
            spaced = @('a', 'b')
            piped  = @('a', 'b')
            filter = [ordered]@{ status = 'open'; owner = 'me' }
            raw    = 'a/b?c'
            flag   = $true
            since  = (New-Object System.DateTime -ArgumentList 2024, 1, 2, 3, 4, 5, ([System.DateTimeKind]::Utc))
        }
        $null = Invoke-OpenApiRequest -Service 'Ser' -Operation $script:operation -PathParameters @{ id = 1; parts = 'p' } -QueryParameters $query
        # System.Uri escapes '|' as %7C on .NET Core; both mean the same
        $script:server.Requests[0].Query.Replace('%7C', '|') | Should -Be '?tags=red&tags=green&ids=1,2,3&spaced=a%20b&piped=a|b&filter[status]=open&filter[owner]=me&raw=a/b?c&flag=true&since=2024-01-02T03%3A04%3A05.0000000Z'
    }

    It 'sends only the query parameters that were passed' {
        $null = Invoke-OpenApiRequest -Service 'Ser' -Operation $script:operation -PathParameters @{ id = 1; parts = 'p' } -QueryParameters @{}
        $script:server.Requests[0].Query | Should -BeNullOrEmpty
    }

    It 'serialises header parameters with the simple style' {
        $null = Invoke-OpenApiRequest -Service 'Ser' -Operation $script:operation -PathParameters @{ id = 1; parts = 'p' } -HeaderParameters ([ordered]@{ 'X-Ids' = @(1, 2); 'X-Obj' = [ordered]@{ a = 1; b = $false } })
        $script:server.Requests[0].Headers['X-Ids'] | Should -Be '1,2'
        $script:server.Requests[0].Headers['X-Obj'] | Should -Be 'a=1,b=false'
    }

    It 'sends cookie parameters as one Cookie header' {
        $null = Invoke-OpenApiRequest -Service 'Ser' -Operation $script:operation -PathParameters @{ id = 1; parts = 'p' } -CookieParameters ([ordered]@{ prefs = @('a', 'b'); lang = 'en' })
        $script:server.Requests[0].Headers['Cookie'] | Should -Be 'prefs=a,b; lang=en'
    }

    It 'reports a missing path parameter without sending a request' {
        $errors = $null
        $null = Invoke-OpenApiRequest -Service 'Ser' -Operation $script:operation -PathParameters @{ id = 1 } -ErrorAction SilentlyContinue -ErrorVariable errors
        $record = @($errors | Where-Object -FilterScript { $_.FullyQualifiedErrorId -like 'OpenApi.*' })[0]
        $record.FullyQualifiedErrorId | Should -BeLike 'OpenApi.Ser.InvalidArgument*'
        $record.Exception.Message | Should -Match "'parts'"
        $script:server.Requests.Count | Should -Be 0
    }
}
