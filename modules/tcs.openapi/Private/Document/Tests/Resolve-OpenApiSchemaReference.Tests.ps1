BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../../tcs.openapi.psd1') -Force
}

Describe 'Resolve-OpenApiSchemaReference' {
    BeforeAll {
        # Created inside the module so the script block runs in module scope
        $script:newContext = InModuleScope tcs.openapi {
            {
                param([string]$Schemas)
                Get-OpenApiNormalizationContext -Root (ConvertFrom-OpenApiJson -Text ('{"components":{"schemas":' + $Schemas + '}}')) -SourceVersion '3.0.3'
            }
        }
    }

    It 'normalises the target once and returns the cached object afterwards' {
        InModuleScope tcs.openapi -Parameters @{ NewContext = $script:newContext } {
            param($NewContext)
            $context = & $NewContext '{"Pet":{"type":"object"}}'
            $first = Resolve-OpenApiSchemaReference -Context $context -Reference '#/components/schemas/Pet' -Pointer '/a'
            $second = Resolve-OpenApiSchemaReference -Context $context -Reference '#/components/schemas/Pet' -Pointer '/b'
            [object]::ReferenceEquals($first, $second) | Should -BeTrue
            $first.RefName | Should -Be 'Pet'
        }
    }

    It 'resolves #/definitions refs and escaped names' {
        InModuleScope tcs.openapi -Parameters @{ NewContext = $script:newContext } {
            param($NewContext)
            $context = & $NewContext '{"a/b~c":{"type":"string"},"Pet":{"type":"object"}}'
            (Resolve-OpenApiSchemaReference -Context $context -Reference '#/components/schemas/a~1b~0c' -Pointer '').RefName | Should -BeExactly 'a/b~c'
            (Resolve-OpenApiSchemaReference -Context $context -Reference '#/definitions/Pet' -Pointer '').RefName | Should -Be 'Pet'
        }
    }

    It 'marks a circular reference Recursive, does not expand it again and reports OA022 once' {
        InModuleScope tcs.openapi -Parameters @{ NewContext = $script:newContext } {
            param($NewContext)
            $context = & $NewContext '{"Node":{"type":"object","properties":{"next":{"$ref":"#/components/schemas/Node"},"children":{"type":"array","items":{"$ref":"#/components/schemas/Node"}}}}}'
            $node = Resolve-OpenApiSchemaReference -Context $context -Reference '#/components/schemas/Node' -Pointer '/components/schemas/Node'
            $node.Recursive | Should -BeFalse
            $node.Properties['next'].Recursive | Should -BeTrue
            $node.Properties['next'].RefName | Should -Be 'Node'
            $node.Properties['next'].Properties | Should -BeNullOrEmpty
            $node.Properties['children'].Items.Recursive | Should -BeTrue
            @($context.Findings | Where-Object Code -EQ 'OA022').Count | Should -Be 1
            $context.Findings[0].Severity | Should -Be 'Information'
            $context.Findings[0].Pointer | Should -BeExactly '/components/schemas/Node'
            $context.SchemaStack.Count | Should -Be 0
        }
    }

    It 'handles indirect cycles (A -> B -> A)' {
        InModuleScope tcs.openapi -Parameters @{ NewContext = $script:newContext } {
            param($NewContext)
            $context = & $NewContext '{"A":{"properties":{"b":{"$ref":"#/components/schemas/B"}}},"B":{"properties":{"a":{"$ref":"#/components/schemas/A"}}}}'
            $a = Resolve-OpenApiSchemaReference -Context $context -Reference '#/components/schemas/A' -Pointer ''
            $a.Properties['b'].RefName | Should -Be 'B'
            $a.Properties['b'].Recursive | Should -BeFalse
            $b = Resolve-OpenApiSchemaReference -Context $context -Reference '#/components/schemas/B' -Pointer ''
            $b.RefName | Should -Be 'B'
            $b.Properties['a'].RefName | Should -Be 'A'
            $b.Properties['a'].Recursive | Should -BeTrue
            $b.Properties['a'].Type | Should -Be 'object'
            @($context.Findings | Where-Object Code -EQ 'OA022').Pointer | Should -Be @('/components/schemas/A')
        }
    }

    It 'returns reference stubs for nested refs to named schemas and the full schema otherwise' {
        InModuleScope tcs.openapi -Parameters @{ NewContext = $script:newContext } {
            param($NewContext)
            $context = & $NewContext '{"Owner":{"type":"object","description":"o","properties":{"pet":{"$ref":"#/components/schemas/Pet"},"pets":{"type":"array","items":{"$ref":"#/components/schemas/Pet"}}}},"Pet":{"type":"object","required":["id"],"properties":{"id":{"type":"string"}}}}'
            $owner = Resolve-OpenApiSchemaReference -Context $context -Reference '#/components/schemas/Owner' -Pointer ''
            $stub = $owner.Properties['pet']
            $stub.RefName | Should -Be 'Pet'
            $stub.Type | Should -Be 'object'
            $stub.Properties | Should -BeNullOrEmpty
            $stub.Required.Count | Should -Be 0
            $stub.Recursive | Should -BeFalse
            [object]::ReferenceEquals($stub, $owner.Properties['pets'].Items) | Should -BeTrue
            $full = Resolve-OpenApiSchemaReference -Context $context -Reference '#/components/schemas/Pet' -Pointer ''
            $full.Properties['id'].Type | Should -Be 'string'
            $full.Required | Should -Be @('id')
            [object]::ReferenceEquals($full, $stub) | Should -BeFalse
        }
    }

    It 'returns the full schema for a nested ref with -Full' {
        InModuleScope tcs.openapi -Parameters @{ NewContext = $script:newContext } {
            param($NewContext)
            $context = & $NewContext '{"Pet":{"type":"object","properties":{"id":{"type":"string"}}}}'
            [void]$context.SchemaStack.Add('/somewhere')
            (Resolve-OpenApiSchemaReference -Context $context -Reference '#/components/schemas/Pet' -Pointer '').Properties | Should -BeNullOrEmpty
            (Resolve-OpenApiSchemaReference -Context $context -Reference '#/components/schemas/Pet' -Pointer '' -Full).Properties.Count | Should -Be 1
        }
    }

    It 'keeps the serialised size linear for heavily shared references' {
        InModuleScope tcs.openapi -Parameters @{ NewContext = $script:newContext } {
            param($NewContext)
            # S0 -> S1, S1 x2 -> ... -> S30: fully expanded this would be 2^30 nodes
            $parts = foreach ($index in 0..29) {
                '"S{0}":{{"type":"object","properties":{{"a":{{"$ref":"#/components/schemas/S{1}"}},"b":{{"$ref":"#/components/schemas/S{1}"}}}}}}' -f $index, ($index + 1)
            }
            $context = & $NewContext ('{' + ($parts -join ',') + ',"S30":{"type":"string"}}')
            $s0 = Resolve-OpenApiSchemaReference -Context $context -Reference '#/components/schemas/S0' -Pointer ''
            ($s0 | ConvertTo-Json -Depth 100 -Compress).Length | Should -BeLessThan 5000
        }
    }

    It 'gives an alias its own name without renaming the target' {
        InModuleScope tcs.openapi -Parameters @{ NewContext = $script:newContext } {
            param($NewContext)
            $context = & $NewContext '{"Pet":{"type":"object"},"Animal":{"$ref":"#/components/schemas/Pet"}}'
            (Resolve-OpenApiSchemaReference -Context $context -Reference '#/components/schemas/Animal' -Pointer '').RefName | Should -Be 'Animal'
            (Resolve-OpenApiSchemaReference -Context $context -Reference '#/components/schemas/Pet' -Pointer '').RefName | Should -Be 'Pet'
        }
    }

    It 'reports external refs as OA020 and counts them' {
        InModuleScope tcs.openapi -Parameters @{ NewContext = $script:newContext } {
            param($NewContext)
            $context = & $NewContext '{}'
            $schema = Resolve-OpenApiSchemaReference -Context $context -Reference 'common.json#/Pet' -Pointer '/x/schema'
            $schema.Type | Should -BeNullOrEmpty
            $context.ExternalRefHits | Should -Be 1
            $context.Findings[0].Code | Should -Be 'OA020'
            $context.Findings[0].Severity | Should -Be 'Error'
            $context.Findings[0].Pointer | Should -BeExactly '/x/schema'
        }
    }

    It 'counts external refs again when a cached schema that contains one is reused' {
        InModuleScope tcs.openapi -Parameters @{ NewContext = $script:newContext } {
            param($NewContext)
            $context = & $NewContext '{"W":{"properties":{"x":{"$ref":"http://example.com/x.json"}}}}'
            $null = Resolve-OpenApiSchemaReference -Context $context -Reference '#/components/schemas/W' -Pointer ''
            $context.ExternalRefHits | Should -Be 1
            $null = Resolve-OpenApiSchemaReference -Context $context -Reference '#/components/schemas/W' -Pointer ''
            $context.ExternalRefHits | Should -Be 2
        }
    }

    It 'reports unresolved local refs as OA021' {
        InModuleScope tcs.openapi -Parameters @{ NewContext = $script:newContext } {
            param($NewContext)
            $context = & $NewContext '{}'
            $null = Resolve-OpenApiSchemaReference -Context $context -Reference '#/components/schemas/Missing' -Pointer '/p'
            $context.Findings[0].Code | Should -Be 'OA021'
            $context.Findings[0].Severity | Should -Be 'Error'
            $context.ExternalRefHits | Should -Be 0
        }
    }
}
