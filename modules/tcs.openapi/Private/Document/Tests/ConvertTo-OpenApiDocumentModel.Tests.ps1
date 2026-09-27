BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../../tcs.openapi.psd1') -Force
    $script:fixtures = Join-Path -Path $PSScriptRoot -ChildPath '../../../../../tests/Fixtures'
    $script:load = InModuleScope tcs.openapi {
        {
            param([string]$Path, [uri]$BaseUri)
            ConvertTo-OpenApiDocumentModel -Root (ConvertFrom-OpenApiJson -Text ([System.IO.File]::ReadAllText($Path))) -BaseUri $BaseUri
        }
    }
    $script:fromText = InModuleScope tcs.openapi {
        {
            param([string]$Json)
            ConvertTo-OpenApiDocumentModel -Root (ConvertFrom-OpenApiJson -Text $Json)
        }
    }
}

Describe 'ConvertTo-OpenApiDocumentModel' {
    Context 'Model shape' {
        It 'has the documented properties in order and PSTypeName' {
            $model = & $script:load (Join-Path -Path $script:fixtures -ChildPath 'document-petstore-3.0.json')
            $model.PSObject.TypeNames | Should -Contain 'Tcs.OpenApi.Document'
            @($model.PSObject.Properties.Name) | Should -Be @('SourceVersion', 'Title', 'Version', 'Description', 'Servers', 'SecuritySchemes', 'Security', 'Schemas', 'Operations', 'Findings')
        }

        It 'round-trips through ConvertTo-Json' {
            $model = & $script:load (Join-Path -Path $script:fixtures -ChildPath 'document-petstore-3.0.json')
            $json = $model | ConvertTo-Json -Depth 100 -Compress
            $back = $json | ConvertFrom-Json
            $back.Title | Should -Be 'Petstore'
            $back.Operations.Count | Should -Be $model.Operations.Count
            $back.Schemas.Pet.Properties.category.RefName | Should -Be 'Category'
        }

        It 'uses full schemas at operations and reference stubs inside named schemas' {
            $model = & $script:load (Join-Path -Path $script:fixtures -ChildPath 'document-petstore-3.0.json')
            $body = $model.Operations[1].RequestBody.Content[0].Schema
            [object]::ReferenceEquals($body, $model.Schemas['Pet']) | Should -BeTrue
            $body.Properties['category'].RefName | Should -Be 'Category'
            $body.Properties['category'].Type | Should -Be 'object'
            $body.Properties['category'].Properties | Should -BeNullOrEmpty
            $model.Schemas['Category'].Properties.Count | Should -Be 2
            $model.Schemas['PetList'].Properties['value'].Items.RefName | Should -Be 'Pet'
        }

        It 'serialises circular schemas without recursing forever' {
            $model = & $script:load (Join-Path -Path $script:fixtures -ChildPath 'document-circular.json')
            { $model | ConvertTo-Json -Depth 100 -Compress } | Should -Not -Throw
        }
    }

    Context 'Petstore 3.0' {
        BeforeAll {
            $script:model = & $script:load (Join-Path -Path $script:fixtures -ChildPath 'document-petstore-3.0.json')
        }

        It 'reads info' {
            $script:model.SourceVersion | Should -Be '3.0.3'
            $script:model.Title | Should -Be 'Petstore'
            $script:model.Version | Should -Be '1.2.0'
            $script:model.Description | Should -Not -BeNullOrEmpty
        }

        It 'reads servers and variables' {
            $script:model.Servers.Count | Should -Be 2
            $script:model.Servers[0].Variables['region'].Enum | Should -Be @('eu', 'us')
            $script:model.Servers[1].Url | Should -Be '/v1'
        }

        It 'reads security schemes and the default security' {
            @($script:model.SecuritySchemes.Keys) | Should -Be @('api_key', 'basic', 'bearer', 'oauth')
            $script:model.SecuritySchemes['oauth'].Flows['clientCredentials'].TokenUrl | Should -Be 'https://auth.example.com/token'
            $script:model.Security.Count | Should -Be 1
            $script:model.Security[0].Contains('api_key') | Should -BeTrue
        }

        It 'reads component schemas in order with RefName' {
            @($script:model.Schemas.Keys) | Should -Be @('Pet', 'Category', 'PetList', 'Store', 'Error')
            $script:model.Schemas['Pet'].RefName | Should -Be 'Pet'
            $script:model.Schemas['Pet'].Properties['tag'].Nullable | Should -BeTrue
            $script:model.Schemas['Pet'].Properties['born'].Example | Should -BeExactly '2020-01-01T00:00:00Z'
        }

        It 'builds the operations in document order' {
            @($script:model.Operations.OperationId) | Should -Be @('listPets', 'createPet', 'showPetById', 'deletePet', 'uploadPetPhoto', 'getStores')
        }

        It 'resolves parameter, header, request body and response refs' {
            $list = $script:model.Operations[0]
            $list.Parameters[0].Name | Should -Be 'limit'
            $list.Parameters[0].Schema.Maximum | Should -Be 100
            $list.Responses[0].Headers['X-Rate-Limit'].Schema.Type | Should -Be 'integer'
            $list.Responses[1].StatusCode | Should -Be 'default'
            $list.Responses[1].Content[0].ContentType | Should -Be 'application/problem+json'
            $create = $script:model.Operations[1]
            $create.RequestBody.Required | Should -BeTrue
            $create.RequestBody.Content[0].ContentType | Should -Be 'application/json'
            $create.RequestBody.Content[0].Schema.RefName | Should -Be 'Pet'
        }

        It 'detects nextLink and Link-header paging' {
            $script:model.Operations[0].Paging.Kind | Should -Be 'nextLink'
            $script:model.Operations[0].Paging.ItemsProperty | Should -Be 'value'
            $script:model.Operations[5].Paging.Kind | Should -Be 'linkHeader'
            $script:model.Operations[2].Paging | Should -BeNullOrEmpty
        }

        It 'merges the path-level petId parameter' {
            $script:model.Operations[2].Parameters[0].Name | Should -Be 'petId'
            $script:model.Operations[2].Parameters[0].Schema.Format | Should -Be 'int64'
            $script:model.Operations[3].Parameters[0].Name | Should -Be 'petId'
        }

        It 'distinguishes default, none and explicit security' {
            $script:model.Operations[0].Security | Should -BeNullOrEmpty
            $null -eq $script:model.Operations[1].Security | Should -BeFalse
            $script:model.Operations[1].Security.Count | Should -Be 0
            $script:model.Operations[3].Security.Count | Should -Be 2
            $script:model.Operations[3].Security[0]['oauth'] | Should -Be @('pets:write')
        }

        It 'reads Deprecated, ExternalDocsUrl, Tags and extensions' {
            $script:model.Operations[3].Deprecated | Should -BeTrue
            $script:model.Operations[3].Extensions['x-ps-verb'] | Should -Be 'Remove'
            $script:model.Operations[3].Extensions['x-ps-noun'] | Should -Be 'PetRecord'
            $script:model.Operations[4].Extensions['x-ps-name'] | Should -Be 'Set-PetPhoto'
            $script:model.Operations[2].ExternalDocsUrl | Should -Be 'https://docs.example.com/pets#get'
            $script:model.Operations[2].Tags | Should -Be @('pets')
        }

        It 'orders media types JSON first' {
            @($script:model.Operations[2].Responses[0].Content.ContentType) | Should -Be @('application/json', 'application/xml')
        }

        It 'reports OA010, OA051 and OA060' {
            @($script:model.Findings.Code) | Should -Be @('OA010', 'OA051', 'OA060')
            ($script:model.Findings | Where-Object Code -EQ 'OA010').Operation | Should -Be 'getStores'
            ($script:model.Findings | Where-Object Code -EQ 'OA051').Operation | Should -Be 'createPet'
        }
    }

    Context 'OpenAPI 3.1' {
        BeforeAll {
            $script:model = & $script:load (Join-Path -Path $script:fixtures -ChildPath 'document-openapi-3.1.json')
        }

        It 'normalises 3.1 schemas' {
            $item = $script:model.Schemas['Item']
            $item.Properties['id'].Const | Should -Be 'fixed-id'
            $item.Properties['note'].Type | Should -Be 'string'
            $item.Properties['note'].Nullable | Should -BeTrue
            $item.Properties['value'].Type | Should -BeNullOrEmpty
            $item.Properties['nothing'].Nullable | Should -BeTrue
            $item.Properties['sample'].Example | Should -Be 'first'
            $item.Properties['free'].Type | Should -BeNullOrEmpty
        }

        It 'uses x-ms-pageable' {
            $script:model.Operations[0].Paging.ItemsProperty | Should -Be 'items'
            $script:model.Operations[0].Paging.NextLinkProperty | Should -Be '@odata.nextLink'
            $script:model.Operations[2].Paging | Should -BeNullOrEmpty
        }

        It 'reports OA030 for each unsupported scheme and OA031' {
            @($script:model.Findings | Where-Object Code -EQ 'OA030').Count | Should -Be 4
            ($script:model.Findings | Where-Object Code -EQ 'OA031').Pointer | Should -BeExactly '/components/schemas/Item/properties/value/type'
        }

        It 'ignores webhooks' {
            $script:model.Operations.Count | Should -Be 3
        }
    }

    Context 'Swagger 2.0' {
        BeforeAll {
            $script:model = & $script:load (Join-Path -Path $script:fixtures -ChildPath 'document-swagger-2.0.json')
            $script:operations = @{}
            foreach ($operation in $script:model.Operations) {
                $script:operations[$operation.OperationId] = $operation
            }
        }

        It 'reports SourceVersion 2.0 and converts servers' {
            $script:model.SourceVersion | Should -Be '2.0'
            @($script:model.Servers.Url) | Should -Be @('https://petstore.example.com/v2', 'http://petstore.example.com/v2')
        }

        It 'converts definitions to schemas and resolves #/definitions refs' {
            @($script:model.Schemas.Keys) | Should -Be @('Pet', 'Category', 'Error')
            $script:model.Schemas['Pet'].Properties['category'].RefName | Should -Be 'Category'
            $script:operations['findPets'].Responses[0].Content[0].Schema.Items.RefName | Should -Be 'Pet'
        }

        It 'converts security definitions' {
            $script:model.SecuritySchemes['basic_auth'].Type | Should -Be 'http'
            $script:model.SecuritySchemes['basic_auth'].Scheme | Should -Be 'basic'
            $script:model.SecuritySchemes['api_key'].ParameterName | Should -Be 'api_key'
            $script:model.SecuritySchemes['petstore_auth'].Flows['clientCredentials'].Scopes['write:pets'] | Should -Be 'modify pets'
            $finding = $script:model.Findings | Where-Object Code -EQ 'OA030'
            $finding.Pointer | Should -BeExactly '/securityDefinitions/implicit_auth'
        }

        It 'maps collectionFormat to style/explode' {
            $styles = @($script:operations['findPets'].Parameters | ForEach-Object { '{0}={1}/{2}' -f $_.Name, $_.Style, $_.Explode })
            $styles | Should -Be @('tags=form/False', 'status=form/True', 'ids=pipeDelimited/False', 'names=spaceDelimited/False', 'X-Trace=simple/False', 'limit=form/True')
            $script:operations['findPets'].Parameters[5].Schema.Default | Should -Be 20
            $script:operations['findPets'].Parameters[1].Schema.Items.Enum | Should -Be @('available', 'sold')
        }

        It 'converts body, urlencoded formData and multipart formData' {
            $script:operations['addPet'].RequestBody.Content[0].Schema.RefName | Should -Be 'Pet'
            $script:operations['updatePetWithForm'].RequestBody.Content[0].ContentType | Should -Be 'application/x-www-form-urlencoded'
            $script:operations['updatePetWithForm'].RequestBody.Content[0].Schema.Required | Should -Be @('name')
            $upload = $script:operations['uploadImage'].RequestBody.Content[0]
            $upload.ContentType | Should -Be 'multipart/form-data'
            $upload.Schema.Properties['file'].Format | Should -Be 'binary'
        }

        It 'converts responses with produces and headers' {
            @($script:operations['findPets'].Responses[0].Content.ContentType) | Should -Be @('application/json', 'application/xml')
            $script:operations['findPets'].Responses[0].Headers['X-Total'].Schema.Type | Should -Be 'integer'
            $script:operations['findPets'].Responses[1].Description | Should -Be 'Unexpected error'
            $script:operations['getImage'].Responses[0].Content[0].ContentType | Should -Be 'image/png'
            $script:operations['getImage'].Responses[0].Content[0].Schema.Format | Should -Be 'binary'
        }

        It 'merges path-level parameters with operation-level override' {
            $script:operations['deletePet'].Parameters[0].Schema.Type | Should -Be 'string'
            $script:operations['updatePetWithForm'].Parameters[0].Schema.Type | Should -Be 'integer'
        }

        It 'keeps security and extensions' {
            $script:model.Security[0].Contains('api_key') | Should -BeTrue
            $script:operations['deletePet'].Security.Count | Should -Be 0
            $script:operations['addPet'].Security[0]['petstore_auth'] | Should -Be @('write:pets')
            $script:operations['findPets'].Extensions['x-ps-name'] | Should -Be 'Find-Pet'
        }
    }

    Context 'Circular schemas' {
        It 'marks recursion points and reports OA022 once per cycle entry' {
            $model = & $script:load (Join-Path -Path $script:fixtures -ChildPath 'document-circular.json')
            $model.Schemas['Node'].Properties['children'].Items.Recursive | Should -BeTrue
            $model.Schemas['Node'].Properties['parent'].Recursive | Should -BeTrue
            $model.Schemas['Person'].Properties['employer'].RefName | Should -Be 'Company'
            $model.Schemas['Person'].Properties['employer'].Recursive | Should -BeFalse
            $model.Schemas['Person'].Properties['employer'].Properties | Should -BeNullOrEmpty
            $model.Schemas['Company'].Properties['employees'].Items.RefName | Should -Be 'Person'
            $model.Schemas['Company'].Properties['employees'].Items.Recursive | Should -BeTrue
            $model.Schemas['Alias'].RefName | Should -Be 'Alias'
            @($model.Schemas['Alias'].Properties.Keys) | Should -Be @('name', 'children', 'parent')
            $model.Schemas['Node'].RefName | Should -Be 'Node'
            @($model.Findings | Where-Object Code -EQ 'OA022').Count | Should -Be 2
            @($model.Findings | Where-Object Severity -NE 'Information').Count | Should -Be 0
            $model.Operations[0].Responses[0].Content[0].Schema.RefName | Should -Be 'Node'
            $model.Operations[1].RequestBody.Content[0].Schema.Properties['employer'].RefName | Should -Be 'Company'
        }
    }

    Context 'External references' {
        BeforeAll {
            $script:model = & $script:load (Join-Path -Path $script:fixtures -ChildPath 'document-external-ref.json')
        }

        It 'flags the operations that use external refs as Unsupported' {
            @($script:model.Operations | Where-Object Unsupported | ForEach-Object OperationId) | Should -Be @('getRemote', 'getWrapped', 'getShared')
        }

        It 'reports OA020 with pointers and OA021 for unresolved local refs' {
            $external = @($script:model.Findings | Where-Object Code -EQ 'OA020')
            @($external.Pointer) | Should -Be @('/components/schemas/Wrapper/properties/inner', '/paths/~1remote/get/parameters/0/schema', '/paths/~1wrapped/get', '/paths/~1shared/get/parameters/0')
            @($external.Severity | Select-Object -Unique) | Should -Be @('Error')
            ($script:model.Findings | Where-Object Code -EQ 'OA021').Operation | Should -Be 'getMissing'
        }

        It 'drops a parameter whose $ref is external' {
            ($script:model.Operations | Where-Object OperationId -EQ 'getShared').Parameters.Count | Should -Be 0
        }
    }

    Context 'Path-level parameters and operationIds' {
        BeforeAll {
            $script:model = & $script:load (Join-Path -Path $script:fixtures -ChildPath 'document-path-parameters.json')
        }

        It 'merges path-level parameters and resolves parameter ref chains' {
            $list = $script:model.Operations[0]
            @($list.Parameters | ForEach-Object { '{0}:{1}' -f $_.In, $_.Name }) | Should -Be @('path:userId', 'header:x-request-id', 'query:page', 'query:filter', 'cookie:session', 'query:path', 'query:coords', 'path:ids')
            $list.Parameters[1].Description | Should -Be 'Operation-level header wins'
            $list.Parameters[3].Style | Should -Be 'deepObject'
            $list.Parameters[3].Schema.AdditionalProperties.Type | Should -Be 'string'
            $list.Parameters[4].Style | Should -Be 'form'
            $list.Parameters[5].AllowReserved | Should -BeTrue
            $list.Parameters[6].Schema.Properties['lat'].Type | Should -Be 'number'
            $list.Parameters[7].Style | Should -Be 'label'
            $list.Parameters[7].Explode | Should -BeTrue
            $list.Parameters[7].Required | Should -BeTrue
        }

        It 'renames duplicate operationIds (case-insensitively) with OA011' {
            @($script:model.Operations.OperationId) | Should -Be @('listOrders', 'listOrders_2', 'LISTORDERS_3', 'getUsersUserIdOrdersOrderId', 'patchUsersUserIdOrdersOrderId', 'getRoot_2', 'getRoot')
            $duplicates = @($script:model.Findings | Where-Object Code -EQ 'OA011')
            $duplicates.Count | Should -Be 2
            $duplicates[0].Pointer | Should -BeExactly '/paths/~1users~1{userId}~1orders/post/operationId'
        }

        It 'generates missing operationIds with OA010, avoiding explicit ids' {
            $generated = @($script:model.Findings | Where-Object Code -EQ 'OA010')
            @($generated.Operation) | Should -Be @('getUsersUserIdOrdersOrderId', 'patchUsersUserIdOrdersOrderId', 'getRoot_2')
            $generated[0].Pointer | Should -BeExactly '/paths/~1users~1{userId}~1orders~1{order-id}/get'
        }

        It 'resolves escaped and percent-encoded schema refs' {
            $script:model.Operations[3].Parameters[1].Schema.RefName | Should -BeExactly 'a/b~c'
            $script:model.Operations[4].Parameters[1].Schema.RefName | Should -BeExactly 'with space'
            $script:model.Operations[4].Parameters[1].Schema.Format | Should -Be 'uuid'
        }
    }

    Context 'Composition' {
        BeforeAll {
            $script:model = & $script:load (Join-Path -Path $script:fixtures -ChildPath 'document-composition.json')
        }

        It 'merges allOf into Properties and Required' {
            $dog = $script:model.Schemas['Dog']
            $dog.Type | Should -Be 'object'
            @($dog.Properties.Keys) | Should -Be @('name', 'kind', 'id', 'secret', 'bark')
            $dog.Properties['name'].Description | Should -Be 'Dog name overrides Pet name'
            $dog.Required | Should -Be @('name', 'bark')
            $dog.AllOf.Count | Should -Be 2
            $dog.Properties['id'].ReadOnly | Should -BeTrue
            $dog.Properties['secret'].WriteOnly | Should -BeTrue
        }

        It 'keeps oneOf and the discriminator' {
            $animal = $script:model.Schemas['Animal']
            @($animal.OneOf.RefName) | Should -Be @('Dog', 'Cat')
            $animal.Discriminator.PropertyName | Should -Be 'kind'
            $script:model.Schemas['Pet'].Discriminator.Mapping['dog'] | Should -Be '#/components/schemas/Dog'
        }

        It 'handles nullable allOf wrappers, additionalProperties and inferred types' {
            $script:model.Schemas['NullablePet'].Nullable | Should -BeTrue
            $script:model.Schemas['NullablePet'].Description | Should -Be 'A pet or null'
            $script:model.Schemas['NullablePet'].Properties.Count | Should -Be 4
            $script:model.Schemas['Tags'].AdditionalProperties.Type | Should -Be 'string'
            $script:model.Schemas['Closed'].AdditionalProperties | Should -BeFalse
            $script:model.Schemas['Closed'].Type | Should -Be 'object'
            $script:model.Schemas['Matrix'].Type | Should -Be 'array'
            $script:model.Schemas['Matrix'].Items.Items.Type | Should -Be 'number'
            $script:model.Schemas['PetWithNote'].Description | Should -Be 'Sibling description is applied to a copy'
            $script:model.Schemas['Pet'].Description | Should -BeNullOrEmpty
        }

        It 'orders JSON media types first and reports OA050 for oneOf/anyOf bodies' {
            @($script:model.Operations[1].RequestBody.Content.ContentType) | Should -Be @('application/json', 'application/vnd.api+json', 'text/plain')
            @($script:model.Findings | Where-Object Code -EQ 'OA050' | ForEach-Object Operation) | Should -Be @('createAnimal', 'replaceAnimal')
        }

        It 'keeps multipart encodings' {
            $form = $script:model.Operations[3].RequestBody.Content
            $form[0].ContentType | Should -Be 'multipart/form-data'
            $form[0].Encoding['meta'].ContentType | Should -Be 'application/json'
            $form[1].ContentType | Should -Be 'application/x-www-form-urlencoded'
        }
    }

    Context 'Invalid documents' {
        It 'returns OA001 and no operations for an unsupported version' {
            $model = & $script:fromText '{"openapi":"4.0.0","paths":{"/a":{"get":{}}}}'
            $model.Findings.Count | Should -Be 1
            $model.Findings[0].Code | Should -Be 'OA001'
            $model.Findings[0].Severity | Should -Be 'Error'
            $model.Findings[0].Pointer | Should -BeExactly '/openapi'
            $model.Operations.Count | Should -Be 0
            $model.SourceVersion | Should -Be '4.0.0'
        }

        It 'reports missing paths as OA002 (<Severity> for <Version>)' -TestCases @(
            @{ Json = '{"openapi":"3.0.0","info":{}}'; Severity = 'Error'; Version = '3.0' }
            @{ Json = '{"swagger":"2.0","info":{}}'; Severity = 'Error'; Version = '2.0' }
            @{ Json = '{"openapi":"3.1.0","info":{},"webhooks":{}}'; Severity = 'Warning'; Version = '3.1' }
        ) {
            $model = & $script:fromText $Json
            $model.Findings[0].Code | Should -Be 'OA002'
            $model.Findings[0].Severity | Should -Be $Severity
            $model.Findings[0].Pointer | Should -BeExactly '/paths'
        }

        It 'reports an unresolved Swagger 2.0 parameter ref as OA021' {
            $model = & $script:fromText '{"swagger":"2.0","paths":{"/a":{"get":{"operationId":"a","parameters":[{"$ref":"#/parameters/nope"}],"responses":{}}}}}'
            $model.Findings[0].Code | Should -Be 'OA021'
            $model.Findings[0].Operation | Should -Be 'a'
        }

        It 'handles an external path item ref' {
            $model = & $script:fromText '{"openapi":"3.0.0","paths":{"/a":{"$ref":"other.json#/paths/a"}}}'
            $model.Operations.Count | Should -Be 0
            $model.Findings[0].Code | Should -Be 'OA020'
        }

        It 'resolves relative servers against the document URL' {
            $model = & $script:load (Join-Path -Path $script:fixtures -ChildPath 'document-petstore-3.0.json') 'https://petstore.example.com/docs/openapi.json'
            $model.Servers[1].Url | Should -Be 'https://petstore.example.com/v1'
        }
    }
}
