BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../../tcs.openapi.psd1') -Force
}

Describe 'ConvertTo-OpenApiSchemaStub' {
    It 'keeps scalar keywords and drops nested structure' {
        InModuleScope tcs.openapi {
            $context = Get-OpenApiNormalizationContext -Root $null
            $schema = ConvertTo-OpenApiSchema -Context $context -Pointer '' -Node (ConvertFrom-OpenApiJson -Text '{"type":"object","description":"d","nullable":true,"readOnly":true,"required":["a"],"properties":{"a":{"type":"string"}},"additionalProperties":{"type":"string"},"allOf":[{"type":"object"}],"oneOf":[{"type":"object"}],"anyOf":[{"type":"object"}],"discriminator":{"propertyName":"a"}}')
            $schema.RefName = 'Thing'
            $stub = ConvertTo-OpenApiSchemaStub -Schema $schema
            $stub.PSObject.TypeNames | Should -Contain 'Tcs.OpenApi.Schema'
            $stub.RefName | Should -Be 'Thing'
            $stub.Type | Should -Be 'object'
            $stub.Description | Should -Be 'd'
            $stub.Nullable | Should -BeTrue
            $stub.ReadOnly | Should -BeTrue
            foreach ($name in 'Properties', 'AdditionalProperties', 'AllOf', 'OneOf', 'AnyOf', 'Discriminator') {
                $stub.$name | Should -BeNullOrEmpty
            }
            $stub.Required.Count | Should -Be 0
            $schema.Properties.Count | Should -Be 1
        }
    }

    It 'keeps boolean additionalProperties, enums and a stub of the items' {
        InModuleScope tcs.openapi {
            $context = Get-OpenApiNormalizationContext -Root $null
            $schema = ConvertTo-OpenApiSchema -Context $context -Pointer '' -Node (ConvertFrom-OpenApiJson -Text '{"type":"array","additionalProperties":false,"items":{"type":"string","enum":["a","b"],"properties":{"x":{}}}}')
            $stub = ConvertTo-OpenApiSchemaStub -Schema $schema
            $stub.AdditionalProperties | Should -BeFalse
            $stub.Items.Enum | Should -Be @('a', 'b')
            $stub.Items.Properties | Should -BeNullOrEmpty
            $schema.Items.Properties.Count | Should -Be 1
        }
    }
}
