BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../../tcs.openapi.psd1') -Force
}

Describe 'Get-OpenApiBlankSchema' {
    It 'has every property of the document model schema' {
        InModuleScope tcs.openapi {
            $schema = Get-OpenApiBlankSchema
            $schema.PSObject.TypeNames | Should -Contain 'Tcs.OpenApi.Schema'
            foreach ($name in 'Type', 'Format', 'Nullable', 'Enum', 'Default', 'Const', 'Items', 'Properties', 'Required', 'AdditionalProperties',
                'AllOf', 'OneOf', 'AnyOf', 'Discriminator', 'ReadOnly', 'WriteOnly', 'Description', 'RefName', 'Recursive') {
                $schema.PSObject.Properties.Name | Should -Contain $name
            }
        }
    }

    It 'defaults to an untyped, non-nullable schema with no required properties' {
        InModuleScope tcs.openapi {
            $schema = Get-OpenApiBlankSchema
            $schema.Type | Should -BeNullOrEmpty
            $schema.Nullable | Should -BeFalse
            $schema.Recursive | Should -BeFalse
            $schema.Required.Count | Should -Be 0
        }
    }

    It 'returns a new object each time' {
        InModuleScope tcs.openapi {
            $first = Get-OpenApiBlankSchema
            $first.Type = 'string'
            (Get-OpenApiBlankSchema).Type | Should -BeNullOrEmpty
        }
    }
}
