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
        'GET /pets'         = @{ Body = '{"value":[{"id":1},{"id":2}],"nextLink":"{{BaseUri}}/pets/page2?skip=2"}'; ContentType = 'application/json' }
        'GET /pets/page2'   = @{ Body = '{"value":[{"id":3}],"nextLink":"page3"}'; ContentType = 'application/json' }
        'GET /pets/page3'   = @{ Body = '{"value":[{"id":4}]}'; ContentType = 'application/json' }
        'GET /users'        = {
            param($Request)
            if ($Request.Query -eq '?page=2') {
                return @{ Body = '[{"id":"c"}]'; ContentType = 'application/json'; Headers = @{ Link = '<{{BaseUri}}/users?page=1>; rel="prev"' } }
            }
            return @{ Body = '[{"id":"a"},{"id":"b"}]'; ContentType = 'application/json'; Headers = @{ Link = '<{{BaseUri}}/users?page=2>; rel="next", <{{BaseUri}}/users?page=9>; rel="last"' } }
        }
        'GET /odata'        = @{ Body = '{"value":[{"id":1}],"@odata.nextLink":"http://other.invalid/odata?page=2"}'; ContentType = 'application/json' }
        'GET /loop'         = @{ Body = '{"items":[{"id":1}],"next":"/loop"}'; ContentType = 'application/json' }
        'GET /hosts'        = {
            param($Request)
            if ($Request.Query -match 'nextToken=T2') {
                return @{ Body = '{"data":[{"id":4}],"httpStatusCode":200}'; ContentType = 'application/json' }
            }
            if ($Request.Query -match 'nextToken=T1') {
                return @{ Body = '{"data":[{"id":3}],"nextToken":"T2"}'; ContentType = 'application/json' }
            }
            return @{ Body = '{"data":[{"id":1},{"id":2}],"nextToken":"T1"}'; ContentType = 'application/json' }
        }
        'POST /search'      = {
            param($Request)
            if ($Request.Query -match 'cursor=C1') {
                return @{ Body = '{"results":[{"id":"b"}],"next_cursor":""}'; ContentType = 'application/json' }
            }
            return @{ Body = '{"results":[{"id":"a"}],"next_cursor":"C1"}'; ContentType = 'application/json' }
        }
        'GET /tokenloop'    = @{ Body = '{"data":[{"id":1}],"nextToken":"same"}'; ContentType = 'application/json' }
    }
    Set-OpenApiContext -Service 'Page' -BaseUri $script:server.BaseUri

    $script:pets = @{
        OperationId      = 'listPets'
        Method           = 'GET'
        Path             = '/pets'
        Security         = @()
        Paging           = @{ Kind = 'nextLink'; ItemsProperty = 'value'; NextLinkProperty = 'nextLink' }
        ResponseTypeName = 'Page.Pet'
    }
}

AfterAll {
    $script:server.Stop()
    Remove-Module -Name tcs.openapi -Force -ErrorAction SilentlyContinue
}

Describe 'Invoke-OpenApiRequest paging (end to end)' {
    BeforeEach {
        $script:server.Requests.Clear()
    }

    It 'returns the items of one page without -All' {
        $items = @(Invoke-OpenApiRequest -Service 'Page' -Operation $script:pets)
        $items.id | Should -Be @(1, 2)
        $script:server.Requests.Count | Should -Be 1
    }

    It 'follows nextLink (absolute and relative) with -All and types every item' {
        $items = @(Invoke-OpenApiRequest -Service 'Page' -Operation $script:pets -All)
        $items.id | Should -Be @(1, 2, 3, 4)
        $items | ForEach-Object -Process { $_.PSObject.TypeNames[0] | Should -Be 'Page.Pet' }
        @($script:server.Requests | ForEach-Object -Process { $_.RawUrl }) | Should -Be @('/pets', '/pets/page2?skip=2', '/pets/page3')
    }

    It 'streams items: stopping the pipeline early fetches no more pages' {
        $first = Invoke-OpenApiRequest -Service 'Page' -Operation $script:pets -All | Select-Object -First 1
        $first.id | Should -Be 1
        $script:server.Requests.Count | Should -Be 1
    }

    It 'follows a Link rel="next" header' {
        $operation = @{ OperationId = 'listUsers'; Method = 'GET'; Path = '/users'; Security = @(); Paging = @{ Kind = 'linkHeader' } }
        $items = @(Invoke-OpenApiRequest -Service 'Page' -Operation $operation -All)
        $items.id | Should -Be @('a', 'b', 'c')
        $script:server.Requests.Count | Should -Be 2
    }

    It 'does not follow a next link to another host' {
        $operation = @{ OperationId = 'odata'; Method = 'GET'; Path = '/odata'; Security = @(); Paging = @{ Kind = 'nextLink'; ItemsProperty = 'value'; NextLinkProperty = '@odata.nextLink' } }
        $warnings = $null
        $items = @(Invoke-OpenApiRequest -Service 'Page' -Operation $operation -All -WarningVariable warnings -WarningAction SilentlyContinue)
        $items.Count | Should -Be 1
        $script:server.Requests.Count | Should -Be 1
        $warnings[0].Message | Should -Match 'another host'
    }

    It 'returns the items of one page for token paging without -All' {
        $operation = @{ OperationId = 'listHosts'; Method = 'GET'; Path = '/hosts'; Security = @(); Paging = @{ Kind = 'token'; ItemsProperty = 'data'; TokenParameter = 'nextToken'; TokenProperty = 'nextToken' }; ResponseTypeName = 'Page.Host' }
        $verbose = @(Invoke-OpenApiRequest -Service 'Page' -Operation $operation -Verbose 4>&1 | Where-Object -FilterScript { $_ -is [System.Management.Automation.VerboseRecord] })
        $items = @(Invoke-OpenApiRequest -Service 'Page' -Operation $operation)
        $items.id | Should -Be @(1, 2)
        $items[0].PSObject.TypeNames[0] | Should -Be 'Page.Host'
        $script:server.Requests.Count | Should -Be 2
        @($verbose | Where-Object -FilterScript { $_.Message -match '-All' }).Count | Should -Be 1
    }

    It 'follows the token with -All, keeping the other query parameters' {
        $operation = @{ OperationId = 'listHosts'; Method = 'GET'; Path = '/hosts'; Security = @(); Paging = @{ Kind = 'token'; ItemsProperty = 'data'; TokenParameter = 'nextToken'; TokenProperty = 'nextToken' } }
        $items = @(Invoke-OpenApiRequest -Service 'Page' -Operation $operation -QueryParameters @{ pageSize = 2 } -All)
        $items.id | Should -Be @(1, 2, 3, 4)
        @($script:server.Requests | ForEach-Object -Process { $_.RawUrl }) | Should -Be @('/hosts?pageSize=2', '/hosts?pageSize=2&nextToken=T1', '/hosts?pageSize=2&nextToken=T2')
    }

    It 'replaces a token the caller passed and repeats the method and body' {
        $operation = @{ OperationId = 'search'; Method = 'POST'; Path = '/search'; Security = @(); Paging = @{ Kind = 'token'; ItemsProperty = 'results'; TokenParameter = 'cursor'; TokenProperty = 'next_cursor' } }
        $items = @(Invoke-OpenApiRequest -Service 'Page' -Operation $operation -QueryParameters @{ cursor = 'C0' } -Body @{ q = 'x' } -All)
        $items.id | Should -Be @('a', 'b')
        @($script:server.Requests | ForEach-Object -Process { $_.Method + ' ' + $_.RawUrl + ' ' + $_.Body }) | Should -Be @('POST /search?cursor=C0 {"q":"x"}', 'POST /search?cursor=C1 {"q":"x"}')
    }

    It 'follows the token with -All -Raw' {
        $operation = @{ OperationId = 'listHosts'; Method = 'GET'; Path = '/hosts'; Security = @(); Paging = @{ Kind = 'token'; ItemsProperty = 'data'; TokenParameter = 'nextToken'; TokenProperty = 'nextToken' } }
        $pages = @(Invoke-OpenApiRequest -Service 'Page' -Operation $operation -All -Raw)
        $pages.Count | Should -Be 3
        $pages[0].Content | Should -Match '"T1"'
    }

    It 'stops when a token repeats' {
        $operation = @{ OperationId = 'tokenloop'; Method = 'GET'; Path = '/tokenloop'; Security = @(); Paging = @{ Kind = 'token'; ItemsProperty = 'data'; TokenParameter = 'nextToken'; TokenProperty = 'nextToken' } }
        $warnings = $null
        $items = @(Invoke-OpenApiRequest -Service 'Page' -Operation $operation -All -WarningVariable warnings -WarningAction SilentlyContinue)
        $items.Count | Should -Be 2
        $script:server.Requests.Count | Should -Be 2
        $warnings[0].Message | Should -Match 'same'
    }

    It 'writes neither a warning nor an error with -WarningAction Ignore' {
        $operation = @{ OperationId = 'loop'; Method = 'GET'; Path = '/loop'; Security = @(); Paging = @{ Kind = 'nextLink'; ItemsProperty = 'items'; NextLinkProperty = 'next' } }
        $errors = $null
        $output = @(Invoke-OpenApiRequest -Service 'Page' -Operation $operation -All -WarningAction Ignore -ErrorVariable errors 3>&1)
        $output.Count | Should -Be 1
        $output[0] | Should -Not -BeOfType ([System.Management.Automation.WarningRecord])
        @($errors).Count | Should -Be 0
    }

    It 'stops when a next link repeats' {
        $operation = @{ OperationId = 'loop'; Method = 'GET'; Path = '/loop'; Security = @(); Paging = @{ Kind = 'nextLink'; ItemsProperty = 'items'; NextLinkProperty = 'next' } }
        $items = @(Invoke-OpenApiRequest -Service 'Page' -Operation $operation -All -WarningAction SilentlyContinue)
        $items.Count | Should -Be 1
        $script:server.Requests.Count | Should -Be 1
    }
}
