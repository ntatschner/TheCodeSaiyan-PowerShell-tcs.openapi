BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../../tcs.openapi.psd1') -Force
}

Describe 'ConvertTo-OpenApiSchema' {
    BeforeAll {
        # Created inside the module so the script block runs in module scope
        $script:convert = InModuleScope tcs.openapi {
            {
                param([string]$Schema, [string]$Components = '{}')
                $root = ConvertFrom-OpenApiJson -Text ('{"components":{"schemas":' + $Components + '}}')
                $context = Get-OpenApiNormalizationContext -Root $root -SourceVersion '3.1.0'
                $result = ConvertTo-OpenApiSchema -Context $context -Node (ConvertFrom-OpenApiJson -Text $Schema) -Pointer '/s'
                [pscustomobject]@{ Schema = $result; Context = $context }
            }
        }
    }

    It 'copies scalar keywords' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $schema = (& $Convert '{"type":"string","format":"date-time","description":"d","title":"t","pattern":"^a","minLength":1,"maxLength":5,"default":"x","example":"e","enum":["x","y"],"deprecated":true}').Schema
            $schema.Type | Should -Be 'string'
            $schema.Format | Should -Be 'date-time'
            $schema.Description | Should -Be 'd'
            $schema.Title | Should -Be 't'
            $schema.Pattern | Should -Be '^a'
            $schema.MinLength | Should -Be 1
            $schema.MaxLength | Should -Be 5
            $schema.Default | Should -Be 'x'
            $schema.Example | Should -Be 'e'
            $schema.Enum | Should -Be @('x', 'y')
            $schema.Deprecated | Should -BeTrue
            $schema.Nullable | Should -BeFalse
        }
    }

    It 'maps 3.0 nullable' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            (& $Convert '{"type":"string","nullable":true}').Schema.Nullable | Should -BeTrue
        }
    }

    It 'maps 3.1 type arrays with null to Type + Nullable' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $result = & $Convert '{"type":["string","null"]}'
            $result.Schema.Type | Should -Be 'string'
            $result.Schema.Nullable | Should -BeTrue
            $result.Context.Findings.Count | Should -Be 0
        }
    }

    It 'maps type null to an untyped nullable schema' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $schema = (& $Convert '{"type":"null"}').Schema
            $schema.Type | Should -BeNullOrEmpty
            $schema.Nullable | Should -BeTrue
        }
    }

    It 'reports several non-null types as OA031 and leaves Type null' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $result = & $Convert '{"type":["string","integer","null"]}'
            $result.Schema.Type | Should -BeNullOrEmpty
            $result.Schema.Nullable | Should -BeTrue
            $result.Context.Findings[0].Code | Should -Be 'OA031'
            $result.Context.Findings[0].Severity | Should -Be 'Warning'
            $result.Context.Findings[0].Pointer | Should -BeExactly '/s/type'
        }
    }

    It 'keeps const and takes the first of 3.1 examples' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $schema = (& $Convert '{"const":"fixed","examples":["a","b"]}').Schema
            $schema.Const | Should -Be 'fixed'
            $schema.Example | Should -Be 'a'
        }
    }

    It 'normalises items, properties, required and readOnly/writeOnly' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $schema = (& $Convert '{"type":"object","required":["id"],"properties":{"id":{"type":"string","readOnly":true},"pw":{"type":"string","writeOnly":true},"tags":{"type":"array","items":{"type":"string"}}}}').Schema
            @($schema.Properties.Keys) | Should -Be @('id', 'pw', 'tags')
            $schema.Required | Should -Be @('id')
            $schema.Properties['id'].ReadOnly | Should -BeTrue
            $schema.Properties['pw'].WriteOnly | Should -BeTrue
            $schema.Properties['tags'].Items.Type | Should -Be 'string'
        }
    }

    It 'keeps property names that differ only in case' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $schema = (& $Convert '{"type":"object","properties":{"Id":{"type":"string"},"id":{"type":"integer"}}}').Schema
            $schema.Properties['Id'].Type | Should -Be 'string'
            $schema.Properties['id'].Type | Should -Be 'integer'
        }
    }

    It 'maps additionalProperties as a boolean or a schema' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            (& $Convert '{"type":"object","additionalProperties":false}').Schema.AdditionalProperties | Should -BeFalse
            (& $Convert '{"type":"object","additionalProperties":{"type":"integer"}}').Schema.AdditionalProperties.Type | Should -Be 'integer'
            (& $Convert '{"type":"object"}').Schema.AdditionalProperties | Should -BeNullOrEmpty
        }
    }

    It 'infers object and array types when type is missing' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            (& $Convert '{"properties":{"a":{}}}').Schema.Type | Should -Be 'object'
            (& $Convert '{"additionalProperties":true}').Schema.Type | Should -Be 'object'
            (& $Convert '{"items":{"type":"string"}}').Schema.Type | Should -Be 'array'
            (& $Convert '{"description":"any"}').Schema.Type | Should -BeNullOrEmpty
        }
    }

    It 'merges allOf into Properties and Required and keeps AllOf' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $components = '{"Base":{"type":"object","required":["id"],"properties":{"id":{"type":"string"},"name":{"type":"string"}}}}'
            $schema = (& $Convert '{"allOf":[{"$ref":"#/components/schemas/Base"},{"required":["extra"],"properties":{"extra":{"type":"integer"}}}],"properties":{"name":{"type":"string","description":"own wins"}}}' $components).Schema
            $schema.Type | Should -Be 'object'
            @($schema.Properties.Keys) | Should -Be @('id', 'name', 'extra')
            $schema.Properties['name'].Description | Should -Be 'own wins'
            $schema.Required | Should -Be @('id', 'extra')
            $schema.AllOf.Count | Should -Be 2
            $schema.AllOf[0].RefName | Should -Be 'Base'
        }
    }

    It 'takes Type, Format and Enum from a single allOf member and makes it nullable with nullable: true' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $schema = (& $Convert '{"allOf":[{"$ref":"#/components/schemas/Color"}],"nullable":true}' '{"Color":{"type":"string","format":"color","enum":["red","blue"]}}').Schema
            $schema.Type | Should -Be 'string'
            $schema.Format | Should -Be 'color'
            $schema.Enum | Should -Be @('red', 'blue')
            $schema.Nullable | Should -BeTrue
            $schema.RefName | Should -BeNullOrEmpty
        }
    }

    It 'keeps oneOf/anyOf members and the discriminator' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $schema = (& $Convert '{"oneOf":[{"type":"string"},{"type":"integer"}],"anyOf":[{"type":"boolean"}],"discriminator":{"propertyName":"kind","mapping":{"a":"#/components/schemas/A"}}}').Schema
            $schema.OneOf.Count | Should -Be 2
            $schema.OneOf[1].Type | Should -Be 'integer'
            $schema.AnyOf[0].Type | Should -Be 'boolean'
            $schema.Discriminator.PropertyName | Should -Be 'kind'
            $schema.Discriminator.Mapping['a'] | Should -Be '#/components/schemas/A'
            $schema.AllOf | Should -BeNullOrEmpty
        }
    }

    It 'resolves a $ref and sets RefName' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $schema = (& $Convert '{"$ref":"#/components/schemas/Pet"}' '{"Pet":{"type":"object","properties":{"id":{"type":"string"}}}}').Schema
            $schema.RefName | Should -Be 'Pet'
            $schema.Properties['id'].Type | Should -Be 'string'
        }
    }

    It 'applies description and nullable next to a $ref to a copy' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $root = ConvertFrom-OpenApiJson -Text '{"components":{"schemas":{"Pet":{"type":"object","description":"orig"}}}}'
            $context = Get-OpenApiNormalizationContext -Root $root
            $plain = ConvertTo-OpenApiSchema -Context $context -Node (ConvertFrom-OpenApiJson -Text '{"$ref":"#/components/schemas/Pet"}') -Pointer '/a'
            $copy = ConvertTo-OpenApiSchema -Context $context -Node (ConvertFrom-OpenApiJson -Text '{"$ref":"#/components/schemas/Pet","description":"new","nullable":true}') -Pointer '/b'
            $copy.Description | Should -Be 'new'
            $copy.Nullable | Should -BeTrue
            $copy.RefName | Should -Be 'Pet'
            $plain.Description | Should -Be 'orig'
            $plain.Nullable | Should -BeFalse
        }
    }

    It 'turns boolean schemas into blank schemas and ignores non-objects' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            (& $Convert 'true').Schema.PSObject.TypeNames | Should -Contain 'Tcs.OpenApi.Schema'
            (& $Convert '"text"').Schema | Should -BeNullOrEmpty
            $context = Get-OpenApiNormalizationContext -Root $null
            ConvertTo-OpenApiSchema -Context $context -Node $null -Pointer '' | Should -BeNullOrEmpty
        }
    }

    It 'uses the first schema of tuple-style items' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            (& $Convert '{"type":"array","items":[{"type":"integer"},{"type":"string"}]}').Schema.Items.Type | Should -Be 'integer'
        }
    }

    It 'reads only the node itself with -Shallow' {
        InModuleScope tcs.openapi {
            $context = Get-OpenApiNormalizationContext -Root (ConvertFrom-OpenApiJson -Text '{"components":{"schemas":{"X":{"type":"string"}}}}')
            $shallow = ConvertTo-OpenApiSchema -Context $context -Pointer '' -Shallow -Node (ConvertFrom-OpenApiJson -Text '{"description":"d","properties":{"a":{"$ref":"#/components/schemas/X"}},"allOf":[{"$ref":"#/components/schemas/X"}],"items":{"type":"string"}}')
            $shallow.Description | Should -Be 'd'
            $shallow.Type | Should -Be 'object'
            $shallow.Properties | Should -BeNullOrEmpty
            $shallow.AllOf | Should -BeNullOrEmpty
            $shallow.Items | Should -BeNullOrEmpty
            (ConvertTo-OpenApiSchema -Context $context -Pointer '' -Shallow -Node (ConvertFrom-OpenApiJson -Text '{"items":{}}')).Type | Should -Be 'array'
            (ConvertTo-OpenApiSchema -Context $context -Pointer '' -Shallow -Node (ConvertFrom-OpenApiJson -Text '{"$ref":"#/components/schemas/X"}')).Type | Should -BeNullOrEmpty
            $context.SchemaCache.Count | Should -Be 0
        }
    }

    It 'merges allOf members that are reference stubs from their full schema' {
        InModuleScope tcs.openapi {
            $root = ConvertFrom-OpenApiJson -Text '{"components":{"schemas":{"Base":{"type":"object","required":["id"],"properties":{"id":{"type":"string"}}},"Derived":{"allOf":[{"$ref":"#/components/schemas/Base"}],"properties":{"extra":{"type":"integer"}}}}}}'
            $context = Get-OpenApiNormalizationContext -Root $root
            $derived = Resolve-OpenApiSchemaReference -Context $context -Reference '#/components/schemas/Derived' -Pointer ''
            $derived.AllOf[0].Properties | Should -BeNullOrEmpty
            @($derived.Properties.Keys) | Should -Be @('id', 'extra')
            $derived.Required | Should -Be @('id')
        }
    }
}
