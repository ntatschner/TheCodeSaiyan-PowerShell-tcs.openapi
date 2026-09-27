BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../../tcs.openapi.psd1') -Force
}

Describe 'ConvertFrom-OpenApiSwagger2Response' {
    It 'puts the schema under every produces type' {
        InModuleScope tcs.openapi {
            $response = ConvertFrom-OpenApiSwagger2Response -Node (ConvertFrom-OpenApiJson -Text '{"description":"ok","schema":{"$ref":"#/definitions/Pet"},"x-a":1}') -Produces 'application/json', 'application/xml'
            $response['description'] | Should -Be 'ok'
            @($response['content'].Keys) | Should -Be @('application/json', 'application/xml')
            $response['content']['application/xml']['schema']['$ref'] | Should -Be '#/definitions/Pet'
            $response['x-a'] | Should -Be 1
        }
    }

    It 'has no content without a schema and defaults the description' {
        InModuleScope tcs.openapi {
            $response = ConvertFrom-OpenApiSwagger2Response -Node (ConvertFrom-OpenApiJson -Text '{}') -Produces 'application/json'
            $response['description'] | Should -Be ''
            $response.Contains('content') | Should -BeFalse
        }
    }

    It 'converts headers and file schemas' {
        InModuleScope tcs.openapi {
            $response = ConvertFrom-OpenApiSwagger2Response -Node (ConvertFrom-OpenApiJson -Text '{"description":"f","schema":{"type":"file"},"headers":{"X-Rate":{"type":"integer","description":"r"}}}') -Produces 'image/png'
            $response['content']['image/png']['schema']['format'] | Should -Be 'binary'
            $response['headers']['X-Rate']['description'] | Should -Be 'r'
            $response['headers']['X-Rate']['schema']['type'] | Should -Be 'integer'
        }
    }
}
