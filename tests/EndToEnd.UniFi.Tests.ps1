# End to end with a real-world document: tests/Fixtures/unifi-site-manager-1.0.0.json (UniFi Site Manager API)
# -> New-OpenApiModule -NounPrefix UniFi -UnwrapProperty data -> Import-Module (with the real tcs.openapi) ->
# the generated commands against tests/Helpers/TestHttpServer.ps1. It covers what the document needs: router-style
# catch-all paths (/v1/connector/consoles/{id}/*path), nextToken paging, the { data, httpStatusCode, traceId }
# envelope, operationIds that end with the HTTP method (ConnectorGet), an api key header and an array query
# parameter named 'hostIds[]'.

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
        $json = 'application/json'
        if ($Request.Method -eq 'GET' -and $Request.Path -eq '/v1/hosts') {
            if ($Request.RawUrl -match 'nextToken=T2') {
                return @{ Body = '{"code":"SUCCESS","data":[{"id":"h3","type":"network-server"}],"httpStatusCode":200,"traceId":"t2","nextToken":""}'; ContentType = $json }
            }
            return @{ Body = '{"code":"SUCCESS","data":[{"id":"h1","type":"console"},{"id":"h2","type":"console"}],"httpStatusCode":200,"traceId":"t1","nextToken":"T2"}'; ContentType = $json }
        }
        if ($Request.Method -eq 'GET' -and $Request.Path -like '/v1/hosts/*') {
            $id = [System.Uri]::UnescapeDataString($Request.Path.Substring(10))
            return @{ Body = ('{"data":{"id":"' + $id + '","type":"console"},"httpStatusCode":200,"traceId":"t"}'); ContentType = $json }
        }
        if ($Request.Method -eq 'GET' -and $Request.Path -eq '/v1/devices') {
            return @{ Body = '{"code":"SUCCESS","data":[{"hostId":"h1","hostName":"one","devices":[{"id":"d1"}]}],"httpStatusCode":200,"traceId":"t"}'; ContentType = $json }
        }
        if ($Request.Method -eq 'GET' -and $Request.Path -eq '/v1/sd-wan-configs') {
            return @{ Body = '{"data":[{"id":"s1","name":"A"},{"id":"s2","name":"B"}],"httpStatusCode":200,"traceId":"t"}'; ContentType = $json }
        }
        if ($Request.Method -eq 'POST' -and $Request.Path -eq '/v1/isp-metrics/5m/query') {
            return @{ Body = '{"data":{"metrics":[{"metricType":"5m","hostId":"h1","siteId":"s1"}]},"httpStatusCode":200,"traceId":"t"}'; ContentType = $json }
        }
        if ($Request.Path -like '/v1/connector/consoles/*') {
            return @{ Body = ('{"method":"' + $Request.Method + '","count":1,"data":[{"id":"site-1"}]}'); ContentType = $json }
        }
        return @{ StatusCode = 404; Body = '{"code":"not_found","httpStatusCode":404,"message":"not found"}'; ContentType = $json }
    }

    $script:outputRoot = Join-Path -Path $TestDrive -ChildPath 'generated'
    $script:generation = New-EndToEndModule -Fixture 'unifi-site-manager-1.0.0.json' -ModuleName 'UniFi.SiteManager' -NounPrefix 'UniFi' -UnwrapProperty 'data' -OutputPath $script:outputRoot
    Import-Module -Name $script:generation.ManifestPath -Force
    Set-UniFiContext -BaseUri $script:server.BaseUri -ApiKey ((New-Object -TypeName System.Net.NetworkCredential -ArgumentList '', 'unifi-key-1').SecurePassword) -MaxRetries 0
}

AfterAll {
    $script:server.Stop()
    Remove-Module -Name UniFi.SiteManager -Force -ErrorAction SilentlyContinue
    Remove-OpenApiContext -Service 'UniFi.SiteManager' -ErrorAction SilentlyContinue
}

Describe 'UniFi Site Manager module (end to end)' {
    BeforeEach {
        $script:server.Requests.Clear()
    }

    Context 'Generation' {
        It 'generates every operation; the only warning is the rename of queryISPMetrics' {
            @($script:generation.Skipped).Count | Should -Be 0
            $findings = @($script:generation.Findings | Where-Object -FilterScript { $_.Severity -ne 'Information' })
            @($findings | ForEach-Object -Process { '{0} {1}' -f $_.Code, $_.Operation }) | Should -Be @('OA040 queryISPMetrics')
        }

        It 'names the commands from the operationIds, without a trailing HTTP method' {
            $names = @(Get-Command -Module 'UniFi.SiteManager' | ForEach-Object -Process { $_.Name } | Sort-Object)
            $names | Should -Be @(
                'Get-UniFiConnector', 'Get-UniFiContext', 'Get-UniFiDevice', 'Get-UniFiHost', 'Get-UniFiHostById',
                'Get-UniFiIspMetric', 'Get-UniFiIspMetricQuery', 'Get-UniFiSdWanConfig', 'Get-UniFiSdWanConfigById',
                'Get-UniFiSdWanConfigStatus', 'Get-UniFiSite', 'New-UniFiConnector', 'Remove-UniFiConnector',
                'Remove-UniFiContext', 'Set-UniFiConnector', 'Set-UniFiContext', 'Update-UniFiConnector'
            )
        }

        It 'gives the list operations -All and the connector commands -Id and -Path' {
            foreach ($name in @('Get-UniFiHost', 'Get-UniFiDevice', 'Get-UniFiSite')) {
                (Get-Command -Name $name).Parameters.Keys | Should -Contain 'All'
            }
            (Get-Command -Name 'Get-UniFiHostById').Parameters.Keys | Should -Not -Contain 'All'
            foreach ($name in @('Get-UniFiConnector', 'New-UniFiConnector', 'Set-UniFiConnector', 'Update-UniFiConnector', 'Remove-UniFiConnector')) {
                (Get-Command -Name $name).Parameters.Keys | Should -Contain 'Id'
                (Get-Command -Name $name).Parameters.Keys | Should -Contain 'Path'
            }
        }

        It 'gives -WhatIf and -Confirm to the commands that change state, not to the Get commands' {
            foreach ($command in @(Get-Command -Module 'UniFi.SiteManager' -Verb 'Get')) {
                $command.Parameters.Keys | Should -Not -Contain 'WhatIf' -Because $command.Name
                $command.Parameters.Keys | Should -Not -Contain 'Confirm' -Because $command.Name
            }
            foreach ($name in @('New-UniFiConnector', 'Set-UniFiConnector', 'Update-UniFiConnector', 'Remove-UniFiConnector')) {
                (Get-Command -Name $name).Parameters.Keys | Should -Contain 'WhatIf'
            }
        }

        It 'shows the api key and the default server in the README' {
            $readme = Get-Content -LiteralPath (Join-Path -Path $script:generation.Path -ChildPath 'README.md') -Raw
            $readme | Should -Match ([regex]::Escape("Set-UniFiContext -ApiKey (Read-Host -AsSecureString -Prompt 'API key')"))
            $readme | Should -Not -Match 'Set-UniFiContext -BaseUri'
            $readme | Should -Not -Match 'BearerToken'
            (Get-Command -Name 'Set-UniFiContext').Parameters['BaseUri'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] })[0].Mandatory | Should -BeFalse
        }
    }

    Context 'Calls' {
        It 'sends the api key in the X-API-Key header' {
            $null = Get-UniFiHostById -Id 'h1'
            $script:server.Requests[0].Headers['X-API-Key'] | Should -Be 'unifi-key-1'
        }

        It 'returns the host, not the data envelope, with -UnwrapProperty data' {
            $hostObject = Get-UniFiHostById -Id '900A6F:123'
            $hostObject.id | Should -Be '900A6F:123'
            $hostObject.PSObject.Properties.Name | Should -Not -Contain 'traceId'
            $script:server.Requests[0].RawUrl | Should -Be '/v1/hosts/900A6F%3A123'
        }

        It 'returns the whole response with -Raw' {
            (Get-UniFiHostById -Id 'h1' -Raw).Content | Should -Match '"traceId"'
        }

        It 'unwraps an array in data item by item' {
            $configs = @(Get-UniFiSdWanConfig)
            $configs.id | Should -Be @('s1', 's2')
        }

        It 'returns the hosts of one page without -All' {
            $hosts = @(Get-UniFiHost -PageSize 2)
            $hosts.id | Should -Be @('h1', 'h2')
            $script:server.Requests.Count | Should -Be 1
            $script:server.Requests[0].RawUrl | Should -Be '/v1/hosts?pageSize=2'
        }

        It 'follows nextToken across pages with -All' {
            $hosts = @(Get-UniFiHost -PageSize 2 -All)
            $hosts.id | Should -Be @('h1', 'h2', 'h3')
            @($script:server.Requests | ForEach-Object -Process { $_.RawUrl }) | Should -Be @('/v1/hosts?pageSize=2', '/v1/hosts?pageSize=2&nextToken=T2')
        }

        It 'sends the hostIds[] array query parameter once per value' {
            $devices = @(Get-UniFiDevice -HostIds 'h1', 'h2')
            $devices[0].hostName | Should -Be 'one'
            Get-EndToEndQueryPair -Request $script:server.Requests[0] | Should -Be @('hostIds%5B%5D=h1', 'hostIds%5B%5D=h2')
        }

        It 'keeps the slashes of the connector -Path' {
            $result = Get-UniFiConnector -Id 'c1' -Path 'proxy/network/integration/v1/sites'
            $script:server.Requests[0].Method | Should -Be 'GET'
            $script:server.Requests[0].RawUrl | Should -Be '/v1/connector/consoles/c1/proxy/network/integration/v1/sites'
            $result.method | Should -Be 'GET'
        }

        It 'sends <Command> as <Method> to the connector path' -TestCases @(
            @{ Command = 'New-UniFiConnector'; Method = 'POST' }
            @{ Command = 'Set-UniFiConnector'; Method = 'PUT' }
            @{ Command = 'Update-UniFiConnector'; Method = 'PATCH' }
            @{ Command = 'Remove-UniFiConnector'; Method = 'DELETE' }
        ) {
            $arguments = @{ Id = 'c1'; Path = '/proxy/network/integration/v1/sites/s1/'; Confirm = $false }
            if ($Method -ne 'DELETE') {
                $arguments['Body'] = @{ action = 'AUTHORIZE_GUEST_ACCESS' }
            }
            $null = & $Command @arguments
            $script:server.Requests[0].Method | Should -Be $Method
            $script:server.Requests[0].RawUrl | Should -Be '/v1/connector/consoles/c1/proxy/network/integration/v1/sites/s1'
            if ($Method -ne 'DELETE') {
                $script:server.Requests[0].Body | Should -Be '{"action":"AUTHORIZE_GUEST_ACCESS"}'
            }
        }

        It 'sends the ISP metrics query as a POST although Get-UniFiIspMetricQuery has no -WhatIf' {
            $result = Get-UniFiIspMetricQuery -Type '5m' -Body @{ sites = @([ordered]@{ hostId = 'h1'; siteId = 's1' }) }
            @($result.metrics).Count | Should -Be 1
            $script:server.Requests[0].Method | Should -Be 'POST'
            $script:server.Requests[0].RawUrl | Should -Be '/v1/isp-metrics/5m/query'
            $script:server.Requests[0].Body | Should -Be '{"sites":[{"hostId":"h1","siteId":"s1"}]}'
        }

        It 'sends nothing for New-UniFiConnector -WhatIf' {
            $null = New-UniFiConnector -Id 'c1' -Path 'proxy/network/x' -Body @{ action = 'x' } -WhatIf
            $script:server.Requests.Count | Should -Be 0
        }
    }
}
