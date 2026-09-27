BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../../tcs.openapi.psd1') -Force
}

Describe 'Get-OpenApiServerList' {
    It 'normalises servers and variables' {
        InModuleScope tcs.openapi {
            $raw = ConvertFrom-OpenApiJson -Text '[{"url":"https://{region}.example.com","description":"d","variables":{"region":{"default":"eu","enum":["eu","us"],"description":"r"}}}]'
            $servers = Get-OpenApiServerList -Servers $raw
            $servers.Count | Should -Be 1
            @($servers[0].PSObject.Properties.Name) | Should -Be @('Url', 'Description', 'Variables')
            $servers[0].Url | Should -Be 'https://{region}.example.com'
            $servers[0].Description | Should -Be 'd'
            $servers[0].Variables['region'].Default | Should -Be 'eu'
            $servers[0].Variables['region'].Enum | Should -Be @('eu', 'us')
        }
    }

    It 'defaults to a single server with url /' {
        InModuleScope tcs.openapi {
            $servers = Get-OpenApiServerList -Servers $null
            $servers.Count | Should -Be 1
            $servers[0].Url | Should -Be '/'
            (Get-OpenApiServerList -Servers @())[0].Url | Should -Be '/'
        }
    }

    It 'resolves relative URLs against the document URL' {
        InModuleScope tcs.openapi {
            $raw = ConvertFrom-OpenApiJson -Text '[{"url":"/v1"},{"url":"https://other.example.com/api"},{"url":"/{version}"}]'
            $servers = Get-OpenApiServerList -Servers $raw -BaseUri 'https://api.example.com/docs/openapi.json'
            $servers[0].Url | Should -Be 'https://api.example.com/v1'
            $servers[1].Url | Should -Be 'https://other.example.com/api'
            $servers[2].Url | Should -Be '/{version}'
        }
    }
}
