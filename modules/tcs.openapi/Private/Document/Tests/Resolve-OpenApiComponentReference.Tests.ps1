BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../../tcs.openapi.psd1') -Force
}

Describe 'Resolve-OpenApiComponentReference' {
    BeforeAll {
        $script:context = InModuleScope tcs.openapi {
            {
                Get-OpenApiNormalizationContext -SourceVersion '3.0.3' -Root (ConvertFrom-OpenApiJson -Text '{
                    "components": {
                        "parameters": { "limit": { "name": "limit", "in": "query" }, "alias": { "$ref": "#/components/parameters/limit" },
                                        "loopA": { "$ref": "#/components/parameters/loopB" }, "loopB": { "$ref": "#/components/parameters/loopA" } }
                    }
                }')
            }
        }
    }

    It 'returns a node without $ref as it is' {
        InModuleScope tcs.openapi -Parameters @{ NewContext = $script:context } {
            param($NewContext)
            $context = & $NewContext
            $node = ConvertFrom-OpenApiJson -Text '{"name":"x","in":"query"}'
            $result = Resolve-OpenApiComponentReference -Context $context -Node $node -Pointer '/paths/~1a/get/parameters/0'
            [object]::ReferenceEquals($result.Node, $node) | Should -BeTrue
            $result.Pointer | Should -BeExactly '/paths/~1a/get/parameters/0'
        }
    }

    It 'follows ref chains and returns the target pointer' {
        InModuleScope tcs.openapi -Parameters @{ NewContext = $script:context } {
            param($NewContext)
            $context = & $NewContext
            $result = Resolve-OpenApiComponentReference -Context $context -Node (ConvertFrom-OpenApiJson -Text '{"$ref":"#/components/parameters/alias"}') -Pointer '/p'
            $result.Node['name'] | Should -Be 'limit'
            $result.Pointer | Should -BeExactly '/components/parameters/limit'
        }
    }

    It 'reports external refs as OA020, counts them and returns null' {
        InModuleScope tcs.openapi -Parameters @{ NewContext = $script:context } {
            param($NewContext)
            $context = & $NewContext
            $context.CurrentOperation = 'op'
            Resolve-OpenApiComponentReference -Context $context -Node (ConvertFrom-OpenApiJson -Text '{"$ref":"https://example.com/p.json#/x"}') -Pointer '/p' | Should -BeNullOrEmpty
            $context.ExternalRefHits | Should -Be 1
            $context.Findings[0].Code | Should -Be 'OA020'
            $context.Findings[0].Operation | Should -Be 'op'
        }
    }

    It 'reports unresolved and circular refs as OA021' {
        InModuleScope tcs.openapi -Parameters @{ NewContext = $script:context } {
            param($NewContext)
            $context = & $NewContext
            Resolve-OpenApiComponentReference -Context $context -Node (ConvertFrom-OpenApiJson -Text '{"$ref":"#/components/parameters/none"}') -Pointer '/a' | Should -BeNullOrEmpty
            Resolve-OpenApiComponentReference -Context $context -Node (ConvertFrom-OpenApiJson -Text '{"$ref":"#/components/parameters/loopA"}') -Pointer '/b' | Should -BeNullOrEmpty
            @($context.Findings.Code) | Should -Be @('OA021', 'OA021')
            $context.Findings[1].Message | Should -BeLike '*circular*'
        }
    }
}
