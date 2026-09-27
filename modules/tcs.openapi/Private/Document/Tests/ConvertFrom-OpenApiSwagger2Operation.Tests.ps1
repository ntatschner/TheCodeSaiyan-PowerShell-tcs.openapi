BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../../tcs.openapi.psd1') -Force
}

Describe 'ConvertFrom-OpenApiSwagger2Operation' {
    BeforeAll {
        $script:convert = InModuleScope tcs.openapi {
            {
                param([string]$Operation, [string]$PathParameters = 'null', [string[]]$Consumes = @(), [string[]]$Produces = @())
                $root = ConvertFrom-OpenApiJson -Text '{
                    "parameters": { "limit": { "name": "limit", "in": "query", "type": "integer" }, "body": { "name": "body", "in": "body", "schema": { "type": "string" } } },
                    "responses": { "Err": { "description": "error", "schema": { "$ref": "#/definitions/Error" } } }
                }'
                ConvertFrom-OpenApiSwagger2Operation -Root $root -Operation (ConvertFrom-OpenApiJson -Text $Operation) -PathParameters (ConvertFrom-OpenApiJson -Text $PathParameters) -Consumes $Consumes -Produces $Produces
            }
        }
    }

    It 'keeps operation fields and x- extensions' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $operation = & $Convert '{"operationId":"a","tags":["t"],"summary":"s","description":"d","deprecated":true,"security":[],"externalDocs":{"url":"u"},"x-ps-name":"Get-A","schemes":["http"]}'
            @($operation.Keys) | Should -Be @('operationId', 'tags', 'summary', 'description', 'deprecated', 'security', 'externalDocs', 'x-ps-name')
        }
    }

    It 'turns the body parameter into a request body for each consumes type' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $operation = & $Convert '{"parameters":[{"name":"body","in":"body","required":true,"description":"b","schema":{"$ref":"#/definitions/Pet"}}]}' 'null' @('application/json', 'text/json')
            $operation['requestBody']['required'] | Should -BeTrue
            $operation['requestBody']['description'] | Should -Be 'b'
            @($operation['requestBody']['content'].Keys) | Should -Be @('application/json', 'text/json')
            $operation['requestBody']['content']['text/json']['schema']['$ref'] | Should -Be '#/definitions/Pet'
            $operation.Contains('parameters') | Should -BeFalse
        }
    }

    It 'uses operation-level consumes and defaults to application/json' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $operation = & $Convert '{"consumes":["application/xml"],"parameters":[{"name":"body","in":"body","schema":{}}]}' 'null' @('application/json')
            @($operation['requestBody']['content'].Keys) | Should -Be @('application/xml')
            $default = & $Convert '{"parameters":[{"$ref":"#/parameters/body"}]}'
            @($default['requestBody']['content'].Keys) | Should -Be @('application/json')
            $default['requestBody']['required'] | Should -BeFalse
        }
    }

    It 'turns formData parameters into an urlencoded object schema' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $operation = & $Convert '{"parameters":[{"name":"name","in":"formData","type":"string","required":true,"description":"n"},{"name":"age","in":"formData","type":"integer"}]}' 'null' @('application/x-www-form-urlencoded', 'multipart/form-data')
            @($operation['requestBody']['content'].Keys) | Should -Be @('application/x-www-form-urlencoded')
            $schema = $operation['requestBody']['content']['application/x-www-form-urlencoded']['schema']
            $schema['type'] | Should -Be 'object'
            @($schema['properties'].Keys) | Should -Be @('name', 'age')
            $schema['properties']['name']['description'] | Should -Be 'n'
            $schema['required'] | Should -Be @('name')
            $operation['requestBody']['required'] | Should -BeTrue
        }
    }

    It 'uses multipart/form-data when a formData parameter is a file' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $operation = & $Convert '{"parameters":[{"name":"meta","in":"formData","type":"string"},{"name":"file","in":"formData","type":"file"}]}' 'null' @('application/x-www-form-urlencoded')
            $schema = $operation['requestBody']['content']['multipart/form-data']['schema']
            $schema['properties']['file']['format'] | Should -Be 'binary'
            $schema.Contains('required') | Should -BeFalse
            $operation['requestBody']['required'] | Should -BeFalse
        }
    }

    It 'uses multipart/form-data when consumes lists only multipart' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $operation = & $Convert '{"consumes":["multipart/form-data"],"parameters":[{"name":"a","in":"formData","type":"string"}]}'
            @($operation['requestBody']['content'].Keys) | Should -Be @('multipart/form-data')
        }
    }

    It 'merges path-level parameters, operation-level wins, and inlines #/parameters refs' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $operation = & $Convert '{"parameters":[{"name":"id","in":"path","type":"string","description":"op"},{"$ref":"#/parameters/limit"}]}' '[{"name":"id","in":"path","type":"integer","description":"path"},{"name":"q","in":"query","type":"string"}]'
            @($operation['parameters'] | ForEach-Object { $_['name'] }) | Should -Be @('id', 'q', 'limit')
            $operation['parameters'][0]['description'] | Should -Be 'op'
            $operation['parameters'][0]['schema']['type'] | Should -Be 'string'
        }
    }

    It 'leaves unresolvable parameter refs for the normaliser' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $operation = & $Convert '{"parameters":[{"$ref":"#/parameters/nope"}]}'
            $operation['parameters'][0]['$ref'] | Should -Be '#/parameters/nope'
        }
    }

    It 'converts responses with produces, inlining #/responses refs' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $operation = & $Convert '{"produces":["application/json"],"responses":{"200":{"description":"ok","schema":{"type":"string"}},"default":{"$ref":"#/responses/Err"},"404":{"$ref":"#/responses/Missing"}}}' 'null' @() @('application/xml')
            @($operation['responses'].Keys) | Should -Be @('200', 'default', '404')
            @($operation['responses']['200']['content'].Keys) | Should -Be @('application/json')
            $operation['responses']['default']['description'] | Should -Be 'error'
            $operation['responses']['404']['$ref'] | Should -Be '#/responses/Missing'
        }
    }
}
