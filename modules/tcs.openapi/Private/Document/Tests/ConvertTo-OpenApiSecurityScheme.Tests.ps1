BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../../tcs.openapi.psd1') -Force
}

Describe 'ConvertTo-OpenApiSecurityScheme' {
    BeforeAll {
        $script:convert = InModuleScope tcs.openapi {
            {
                param([string]$Json)
                $context = Get-OpenApiNormalizationContext -Root $null -SourceVersion '3.0.3'
                $scheme = ConvertTo-OpenApiSecurityScheme -Context $context -Name 'auth' -Node (ConvertFrom-OpenApiJson -Text $Json) -Pointer '/components/securitySchemes/auth'
                [pscustomobject]@{ Scheme = $scheme; Findings = $context.Findings.ToArray() }
            }
        }
    }

    It 'maps apiKey to In and ParameterName' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $result = & $Convert '{"type":"apiKey","name":"X-Key","in":"header"}'
            $result.Scheme.PSObject.TypeNames | Should -Contain 'Tcs.OpenApi.SecurityScheme'
            $result.Scheme.Name | Should -Be 'auth'
            $result.Scheme.Type | Should -Be 'apiKey'
            $result.Scheme.In | Should -Be 'header'
            $result.Scheme.ParameterName | Should -Be 'X-Key'
            $result.Findings.Count | Should -Be 0
        }
    }

    It 'lower-cases http schemes and keeps the bearer format' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $result = & $Convert '{"type":"http","scheme":"Bearer","bearerFormat":"JWT"}'
            $result.Scheme.Scheme | Should -BeExactly 'bearer'
            $result.Scheme.BearerFormat | Should -Be 'JWT'
            $result.Findings.Count | Should -Be 0
            (& $Convert '{"type":"http","scheme":"basic"}').Findings.Count | Should -Be 0
        }
    }

    It 'maps oauth2 flows' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $result = & $Convert '{"type":"oauth2","flows":{"clientCredentials":{"tokenUrl":"https://t","scopes":{"a":"A"}},"authorizationCode":{"authorizationUrl":"https://a","tokenUrl":"https://t","refreshUrl":"https://r","scopes":{}}}}'
            $result.Scheme.Flows['clientCredentials'].TokenUrl | Should -Be 'https://t'
            $result.Scheme.Flows['clientCredentials'].Scopes['a'] | Should -Be 'A'
            $result.Scheme.Flows['authorizationCode'].RefreshUrl | Should -Be 'https://r'
            $result.Findings.Count | Should -Be 0
        }
    }

    It 'reports <Json> as OA030' -TestCases @(
        @{ Json = '{"type":"openIdConnect","openIdConnectUrl":"https://o"}' }
        @{ Json = '{"type":"oauth2","flows":{"implicit":{"authorizationUrl":"https://a","scopes":{}}}}' }
        @{ Json = '{"type":"http","scheme":"digest"}' }
        @{ Json = '{"type":"mutualTLS"}' }
    ) {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert; Json = $Json } {
            param($Convert, $Json)
            $result = & $Convert $Json
            $result.Findings[0].Code | Should -Be 'OA030'
            $result.Findings[0].Severity | Should -Be 'Warning'
            $result.Findings[0].Pointer | Should -BeExactly '/components/securitySchemes/auth'
            $result.Scheme | Should -Not -BeNullOrEmpty
        }
    }
}
