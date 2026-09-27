BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../../tcs.openapi.psd1') -Force
}

Describe 'ConvertTo-OpenApiRequestBody' {
    BeforeAll {
        $script:convert = InModuleScope tcs.openapi {
            {
                param([string]$Json)
                $context = Get-OpenApiNormalizationContext -Root (ConvertFrom-OpenApiJson -Text '{}')
                $context.CurrentOperation = 'op'
                $body = ConvertTo-OpenApiRequestBody -Context $context -Node (ConvertFrom-OpenApiJson -Text $Json) -Pointer '/b'
                [pscustomobject]@{ Body = $body; Findings = $context.Findings.ToArray() }
            }
        }
    }

    It 'returns Required, Description and ordered Content' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $result = & $Convert '{"required":true,"description":"d","content":{"text/plain":{"schema":{"type":"string"}},"application/json":{"schema":{"type":"object"}}}}'
            @($result.Body.PSObject.Properties.Name) | Should -Be @('Required', 'Description', 'Content')
            $result.Body.Required | Should -BeTrue
            $result.Body.Description | Should -Be 'd'
            $result.Body.Content[0].ContentType | Should -Be 'application/json'
            $result.Findings.Count | Should -Be 0
        }
    }

    It 'defaults Required to false' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            (& $Convert '{"content":{"application/json":{}}}').Body.Required | Should -BeFalse
        }
    }

    It 'reports a oneOf/anyOf JSON body as OA050' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $result = & $Convert '{"content":{"application/json":{"schema":{"oneOf":[{"type":"string"},{"type":"integer"}]}}}}'
            $result.Findings[0].Code | Should -Be 'OA050'
            $result.Findings[0].Severity | Should -Be 'Information'
            $result.Findings[0].Operation | Should -Be 'op'
            $result.Findings[0].Pointer | Should -BeExactly '/b/content/application~1json/schema'
            (& $Convert '{"content":{"application/json":{"schema":{"anyOf":[{"type":"string"}]}}}}').Findings[0].Code | Should -Be 'OA050'
        }
    }

    It 'reports media types the runtime cannot serialise as OA051' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $result = & $Convert '{"content":{"application/json":{"schema":{"type":"object"}},"application/xml":{"schema":{"type":"object"}}}}'
            $result.Findings.Count | Should -Be 1
            $result.Findings[0].Code | Should -Be 'OA051'
            $result.Findings[0].Severity | Should -Be 'Warning'
            $result.Findings[0].Pointer | Should -BeExactly '/b/content/application~1xml'
        }
    }
}
