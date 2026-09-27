BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../../tcs.openapi.psd1') -Force
}

Describe 'ConvertFrom-OpenApiSwagger2SimpleSchema' {
    It 'copies type, format, enum, default and validation keywords' {
        InModuleScope tcs.openapi {
            $schema = ConvertFrom-OpenApiSwagger2SimpleSchema -Node (ConvertFrom-OpenApiJson -Text '{"name":"n","in":"query","type":"integer","format":"int32","enum":[1,2],"default":1,"minimum":0,"maximum":9,"multipleOf":1,"x-ext":true,"collectionFormat":"csv"}')
            @($schema.Keys) | Should -Be @('type', 'format', 'enum', 'default', 'maximum', 'minimum', 'multipleOf', 'x-ext')
        }
    }

    It 'converts items recursively and keeps item refs' {
        InModuleScope tcs.openapi {
            $schema = ConvertFrom-OpenApiSwagger2SimpleSchema -Node (ConvertFrom-OpenApiJson -Text '{"type":"array","items":{"type":"array","items":{"type":"string","enum":["a"]}}}')
            $schema['items']['items']['enum'] | Should -Be @('a')
            $ref = ConvertFrom-OpenApiSwagger2SimpleSchema -Node (ConvertFrom-OpenApiJson -Text '{"type":"array","items":{"$ref":"#/definitions/Pet"}}')
            $ref['items']['$ref'] | Should -Be '#/definitions/Pet'
        }
    }

    It 'turns type file into a binary string' {
        InModuleScope tcs.openapi {
            $schema = ConvertFrom-OpenApiSwagger2SimpleSchema -Node (ConvertFrom-OpenApiJson -Text '{"type":"file"}')
            $schema['type'] | Should -Be 'string'
            $schema['format'] | Should -Be 'binary'
        }
    }
}
