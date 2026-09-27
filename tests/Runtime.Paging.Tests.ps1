BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $repoRoot = Split-Path -Path $PSScriptRoot -Parent
    Import-Module -Name (Join-Path -Path $repoRoot -ChildPath 'modules/tcs.openapi/tcs.openapi.psd1') -Force
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

    It 'stops when a next link repeats' {
        $operation = @{ OperationId = 'loop'; Method = 'GET'; Path = '/loop'; Security = @(); Paging = @{ Kind = 'nextLink'; ItemsProperty = 'items'; NextLinkProperty = 'next' } }
        $items = @(Invoke-OpenApiRequest -Service 'Page' -Operation $operation -All -WarningAction SilentlyContinue)
        $items.Count | Should -Be 1
        $script:server.Requests.Count | Should -Be 1
    }
}

Describe 'Get-OpenApiLinkHeaderNext' {
    It 'finds rel="next" among several links' {
        InModuleScope -ModuleName tcs.openapi {
            Get-OpenApiLinkHeaderNext -LinkHeader '<https://a/x?page=1>; rel="prev", <https://a/x?page=3>; rel="next"' | Should -Be 'https://a/x?page=3'
            Get-OpenApiLinkHeaderNext -LinkHeader '</p2>; rel=next' | Should -Be '/p2'
            Get-OpenApiLinkHeaderNext -LinkHeader '</p2>; rel="last"' | Should -BeNullOrEmpty
            Get-OpenApiLinkHeaderNext -LinkHeader @('</a>; rel="prev"', '</b>; rel="next last"') | Should -Be '/b'
        }
    }
}

Describe 'Resolve-OpenApiNextPageUri' {
    It 'resolves relative links and rejects other hosts' {
        InModuleScope -ModuleName tcs.openapi {
            Resolve-OpenApiNextPageUri -Link '?page=2' -CurrentUri 'https://api.example.com/v1/items?page=1' -OriginUri 'https://api.example.com/v1/items' | Should -Be 'https://api.example.com/v1/items?page=2'
            Resolve-OpenApiNextPageUri -Link '/v1/items/next' -CurrentUri 'https://api.example.com/v1/items' -OriginUri 'https://api.example.com/v1/items' | Should -Be 'https://api.example.com/v1/items/next'
            Resolve-OpenApiNextPageUri -Link 'https://evil.example.com/x' -CurrentUri 'https://api.example.com/v1' -OriginUri 'https://api.example.com/v1' -WarningAction SilentlyContinue | Should -BeNullOrEmpty
            Resolve-OpenApiNextPageUri -Link 'http://api.example.com/x' -CurrentUri 'https://api.example.com/v1' -OriginUri 'https://api.example.com/v1' -WarningAction SilentlyContinue | Should -BeNullOrEmpty
        }
    }
}
