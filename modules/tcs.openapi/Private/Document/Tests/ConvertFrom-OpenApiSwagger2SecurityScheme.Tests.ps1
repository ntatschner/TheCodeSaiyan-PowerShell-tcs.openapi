BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../../tcs.openapi.psd1') -Force
}

Describe 'ConvertFrom-OpenApiSwagger2SecurityScheme' {
    It 'maps basic to http basic and keeps the description' {
        InModuleScope tcs.openapi {
            $scheme = ConvertFrom-OpenApiSwagger2SecurityScheme -Node (ConvertFrom-OpenApiJson -Text '{"type":"basic","description":"d","x-a":1}')
            $scheme['type'] | Should -Be 'http'
            $scheme['scheme'] | Should -Be 'basic'
            $scheme['description'] | Should -Be 'd'
            $scheme['x-a'] | Should -Be 1
        }
    }

    It 'keeps apiKey' {
        InModuleScope tcs.openapi {
            $scheme = ConvertFrom-OpenApiSwagger2SecurityScheme -Node (ConvertFrom-OpenApiJson -Text '{"type":"apiKey","name":"k","in":"query"}')
            $scheme['type'] | Should -Be 'apiKey'
            $scheme['name'] | Should -Be 'k'
            $scheme['in'] | Should -Be 'query'
        }
    }

    It 'maps oauth2 flow <Flow> to <Expected>' -TestCases @(
        @{ Flow = 'application'; Expected = 'clientCredentials' }
        @{ Flow = 'implicit'; Expected = 'implicit' }
        @{ Flow = 'password'; Expected = 'password' }
        @{ Flow = 'accessCode'; Expected = 'authorizationCode' }
    ) {
        InModuleScope tcs.openapi -Parameters @{ Flow = $Flow; Expected = $Expected } {
            param($Flow, $Expected)
            $scheme = ConvertFrom-OpenApiSwagger2SecurityScheme -Node (ConvertFrom-OpenApiJson -Text ('{"type":"oauth2","flow":"' + $Flow + '","tokenUrl":"https://t","authorizationUrl":"https://a","scopes":{"s":"S"}}'))
            $scheme['type'] | Should -Be 'oauth2'
            @($scheme['flows'].Keys) | Should -Be @($Expected)
            $scheme['flows'][$Expected]['tokenUrl'] | Should -Be 'https://t'
            $scheme['flows'][$Expected]['scopes']['s'] | Should -Be 'S'
        }
    }
}
