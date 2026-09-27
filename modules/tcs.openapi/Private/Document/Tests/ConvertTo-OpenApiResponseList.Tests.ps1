BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../../tcs.openapi.psd1') -Force
}

Describe 'ConvertTo-OpenApiResponseList' {
    BeforeAll {
        $script:convert = InModuleScope tcs.openapi {
            {
                param([string]$Json)
                $root = ConvertFrom-OpenApiJson -Text '{
                    "components": {
                        "responses": { "NotFound": { "description": "Not found", "content": { "application/json": { "schema": { "type": "object" } } } } },
                        "headers": { "Rate": { "description": "Rate", "required": true, "schema": { "type": "integer" } } }
                    }
                }'
                $context = Get-OpenApiNormalizationContext -Root $root
                $list = ConvertTo-OpenApiResponseList -Context $context -Responses (ConvertFrom-OpenApiJson -Text $Json) -Pointer '/r'
                [pscustomobject]@{ List = $list; Findings = $context.Findings.ToArray() }
            }
        }
    }

    It 'returns responses in document order with the documented shape' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $list = (& $Convert '{"200":{"description":"ok","content":{"application/json":{"schema":{"type":"string"}}}},"default":{"description":"error"}}').List
            @($list.StatusCode) | Should -Be @('200', 'default')
            @($list[0].PSObject.Properties.Name) | Should -Be @('StatusCode', 'Description', 'Content', 'Headers')
            $list[0].Content[0].Schema.Type | Should -Be 'string'
            $list[1].Content.Count | Should -Be 0
            $list[1].Headers.Count | Should -Be 0
        }
    }

    It 'upper-cases range codes' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            (& $Convert '{"2xx":{"description":"ok"},"5XX":{"description":"err"}}').List.StatusCode | Should -Be @('2XX', '5XX')
        }
    }

    It 'resolves response and header refs' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $list = (& $Convert '{"404":{"$ref":"#/components/responses/NotFound"},"200":{"description":"ok","headers":{"X-Rate":{"$ref":"#/components/headers/Rate"},"X-Inline":{"description":"i","schema":{"type":"string"}}}}}').List
            $list[0].Description | Should -Be 'Not found'
            $list[0].Content[0].Schema.Type | Should -Be 'object'
            $list[1].Headers['X-Rate'].Description | Should -Be 'Rate'
            $list[1].Headers['X-Rate'].Required | Should -BeTrue
            $list[1].Headers['X-Rate'].Schema.Type | Should -Be 'integer'
            $list[1].Headers['X-Inline'].Schema.Type | Should -Be 'string'
        }
    }

    It 'skips unresolvable responses with a finding' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $result = & $Convert '{"404":{"$ref":"#/components/responses/Nope"},"200":{"description":"ok"}}'
            $result.List.Count | Should -Be 1
            $result.Findings[0].Code | Should -Be 'OA021'
        }
    }

    It 'returns an empty array when there are no responses' {
        InModuleScope tcs.openapi {
            $context = Get-OpenApiNormalizationContext -Root $null
            $list = ConvertTo-OpenApiResponseList -Context $context -Responses $null -Pointer ''
            , $list | Should -BeOfType [object[]]
            $list.Count | Should -Be 0
        }
    }
}
