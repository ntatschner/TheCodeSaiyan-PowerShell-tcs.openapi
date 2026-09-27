BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../../tcs.openapi.psd1') -Force
}

Describe 'ConvertTo-OpenApiOperation' {
    BeforeAll {
        $script:build = InModuleScope tcs.openapi {
            {
                param([string]$PathItem, [string]$Method = 'get', [string]$Components = '{}')
                $root = ConvertFrom-OpenApiJson -Text ('{"components":' + $Components + '}')
                $context = Get-OpenApiNormalizationContext -Root $root -SourceVersion '3.0.3'
                $item = ConvertFrom-OpenApiJson -Text $PathItem
                $operation = ConvertTo-OpenApiOperation -Context $context -OperationId 'op' -Method $Method -Path '/things/{id}' -Operation $item[$Method] -PathItem $item -PathItemPointer '/paths/~1things~1{id}'
                [pscustomobject]@{ Operation = $operation; Context = $context }
            }
        }
    }

    It 'has the documented properties and PSTypeName' {
        InModuleScope tcs.openapi -Parameters @{ Build = $script:build } {
            param($Build)
            $operation = (& $Build '{"get":{"summary":"s","description":"d","tags":["a","b"],"externalDocs":{"url":"https://docs"},"responses":{"200":{"description":"ok"}}}}').Operation
            $operation.PSObject.TypeNames | Should -Contain 'Tcs.OpenApi.Operation'
            foreach ($name in 'OperationId', 'Method', 'Path', 'Tags', 'Summary', 'Description', 'Deprecated', 'ExternalDocsUrl', 'Parameters', 'RequestBody', 'Responses', 'Security', 'Paging', 'Extensions') {
                $operation.PSObject.Properties.Name | Should -Contain $name
            }
            $operation.OperationId | Should -Be 'op'
            $operation.Method | Should -BeExactly 'GET'
            $operation.Path | Should -Be '/things/{id}'
            $operation.Tags | Should -Be @('a', 'b')
            $operation.Summary | Should -Be 's'
            $operation.Description | Should -Be 'd'
            $operation.ExternalDocsUrl | Should -Be 'https://docs'
            $operation.Deprecated | Should -BeFalse
            $operation.RequestBody | Should -BeNullOrEmpty
            $operation.Unsupported | Should -BeFalse
            $operation.Responses[0].StatusCode | Should -Be '200'
        }
    }

    It 'merges path-level parameters; the operation wins on name and location' {
        InModuleScope tcs.openapi -Parameters @{ Build = $script:build } {
            param($Build)
            $operation = (& $Build '{"parameters":[{"name":"id","in":"path","description":"path level"},{"name":"X-Trace","in":"header"},{"name":"id","in":"query"}],"get":{"parameters":[{"name":"id","in":"path","description":"operation level"},{"name":"x-trace","in":"header","required":true},{"name":"extra","in":"query"}]}}').Operation
            @($operation.Parameters | ForEach-Object { '{0}:{1}' -f $_.In, $_.Name }) | Should -Be @('path:id', 'header:x-trace', 'query:id', 'query:extra')
            $operation.Parameters[0].Description | Should -Be 'operation level'
            $operation.Parameters[1].Required | Should -BeTrue
        }
    }

    It 'resolves parameter and request body refs' {
        InModuleScope tcs.openapi -Parameters @{ Build = $script:build } {
            param($Build)
            $components = '{"parameters":{"limit":{"name":"limit","in":"query","schema":{"type":"integer"}}},"requestBodies":{"Thing":{"required":true,"content":{"application/json":{"schema":{"type":"object"}}}}}}'
            $operation = (& $Build '{"post":{"parameters":[{"$ref":"#/components/parameters/limit"}],"requestBody":{"$ref":"#/components/requestBodies/Thing"}}}' 'post' $components).Operation
            $operation.Parameters[0].Name | Should -Be 'limit'
            $operation.Parameters[0].Schema.Type | Should -Be 'integer'
            $operation.RequestBody.Required | Should -BeTrue
            $operation.RequestBody.Content[0].ContentType | Should -Be 'application/json'
            $operation.Method | Should -Be 'POST'
        }
    }

    It 'keeps Security null when absent, empty for [] and a list otherwise' {
        InModuleScope tcs.openapi -Parameters @{ Build = $script:build } {
            param($Build)
            $components = '{"securitySchemes":{"key":{"type":"apiKey","name":"k","in":"header"}}}'
            (& $Build '{"get":{}}' 'get' $components).Operation.Security | Should -BeNullOrEmpty
            $none = (& $Build '{"get":{"security":[]}}' 'get' $components).Operation.Security
            $null -eq $none | Should -BeFalse
            , $none | Should -BeOfType [object[]]
            $none.Count | Should -Be 0
            $list = (& $Build '{"get":{"security":[{"key":[]}]}}' 'get' $components).Operation.Security
            $list.Count | Should -Be 1
            $list[0].Contains('key') | Should -BeTrue
        }
    }

    It 'keeps x- extensions, including the x-ps overrides' {
        InModuleScope tcs.openapi -Parameters @{ Build = $script:build } {
            param($Build)
            $extensions = (& $Build '{"get":{"x-ps-name":"Get-Thing","x-ps-verb":"Get","x-ps-noun":"Thing","x-other":{"a":1},"summary":"s"}}').Operation.Extensions
            @($extensions.Keys) | Should -Be @('x-ps-name', 'x-ps-verb', 'x-ps-noun', 'x-other')
            $extensions['x-other']['a'] | Should -Be 1
        }
    }

    It 'reports deprecated operations as OA060' {
        InModuleScope tcs.openapi -Parameters @{ Build = $script:build } {
            param($Build)
            $result = & $Build '{"get":{"deprecated":true}}'
            $result.Operation.Deprecated | Should -BeTrue
            $result.Context.Findings[0].Code | Should -Be 'OA060'
            $result.Context.Findings[0].Severity | Should -Be 'Information'
            $result.Context.Findings[0].Operation | Should -Be 'op'
            $result.Context.Findings[0].Pointer | Should -BeExactly '/paths/~1things~1{id}/get/deprecated'
        }
    }

    It 'flags operations with an external $ref as Unsupported' {
        InModuleScope tcs.openapi -Parameters @{ Build = $script:build } {
            param($Build)
            $result = & $Build '{"get":{"responses":{"200":{"description":"","content":{"application/json":{"schema":{"$ref":"other.json#/Thing"}}}}}}}'
            $result.Operation.Unsupported | Should -BeTrue
            @($result.Context.Findings | Where-Object Code -EQ 'OA020').Count | Should -Be 1
            $result.Context.Findings[0].Operation | Should -Be 'op'
        }
    }

    It 'flags operations that reuse a cached schema with an external $ref, with a finding of their own' {
        InModuleScope tcs.openapi {
            $root = ConvertFrom-OpenApiJson -Text '{"components":{"schemas":{"W":{"properties":{"x":{"$ref":"other.json#/X"}}}}}}'
            $context = Get-OpenApiNormalizationContext -Root $root
            $null = Resolve-OpenApiSchemaReference -Context $context -Reference '#/components/schemas/W' -Pointer '/components/schemas/W'
            $item = ConvertFrom-OpenApiJson -Text '{"get":{"responses":{"200":{"description":"","content":{"application/json":{"schema":{"$ref":"#/components/schemas/W"}}}}}}}'
            $operation = ConvertTo-OpenApiOperation -Context $context -OperationId 'getW' -Method 'get' -Path '/w' -Operation $item['get'] -PathItem $item -PathItemPointer '/paths/~1w'
            $operation.Unsupported | Should -BeTrue
            $own = @($context.Findings | Where-Object { $_.Code -eq 'OA020' -and $_.Operation -eq 'getW' })
            $own.Count | Should -Be 1
            $own[0].Pointer | Should -BeExactly '/paths/~1w/get'
            $context.CurrentOperation | Should -BeNullOrEmpty
        }
    }

    It 'detects paging' {
        InModuleScope tcs.openapi -Parameters @{ Build = $script:build } {
            param($Build)
            (& $Build '{"get":{"x-ms-pageable":{"nextLinkName":"nextLink"}}}').Operation.Paging.Kind | Should -Be 'nextLink'
        }
    }

    Context 'path templates' {
        BeforeAll {
            $script:convertPath = InModuleScope tcs.openapi {
                {
                    param([string]$Path, [string]$PathItem)
                    $context = Get-OpenApiNormalizationContext -Root (ConvertFrom-OpenApiJson -Text '{}') -SourceVersion '3.0.3'
                    $item = ConvertFrom-OpenApiJson -Text $PathItem
                    $pointer = Join-OpenApiJsonPointer -Pointer '/paths' -Segment $Path
                    $operation = ConvertTo-OpenApiOperation -Context $context -OperationId 'op' -Method 'get' -Path $Path -Operation $item['get'] -PathItem $item -PathItemPointer $pointer
                    [pscustomobject]@{ Operation = $operation; Findings = @($context.Findings) }
                }
            }
        }

        It 'turns a final catch-all segment <Segment> into {path} and flags the parameter CatchAll' -TestCases @(
            @{ Segment = '*path' }
            @{ Segment = '{path*}' }
        ) {
            InModuleScope tcs.openapi -Parameters @{ Convert = $script:convertPath; Segment = $Segment } {
                param($Convert, $Segment)
                $result = & $Convert "/v1/consoles/{id}/$Segment" '{"get":{"parameters":[{"name":"id","in":"path","required":true},{"name":"path","in":"path","required":true}]}}'
                $result.Operation.Path | Should -BeExactly '/v1/consoles/{id}/{path}'
                $result.Operation.Parameters[0].CatchAll | Should -BeFalse
                $result.Operation.Parameters[1].CatchAll | Should -BeTrue
                $result.Findings.Count | Should -Be 0
            }
        }

        It 'leaves a catch-all segment without a matching path parameter alone' {
            InModuleScope tcs.openapi -Parameters @{ Convert = $script:convertPath } {
                param($Convert)
                $result = & $Convert '/files/*rest' '{"get":{}}'
                $result.Operation.Path | Should -BeExactly '/files/*rest'
                $result.Findings.Count | Should -Be 0
            }
        }

        It 'reports a path parameter that is not in the template as OA023 (Warning)' {
            InModuleScope tcs.openapi -Parameters @{ Convert = $script:convertPath } {
                param($Convert)
                $result = & $Convert '/items/{id}' '{"get":{"parameters":[{"name":"id","in":"path"},{"name":"extra","in":"path"},{"name":"q","in":"query"}]}}'
                $result.Findings.Count | Should -Be 1
                $result.Findings[0].Code | Should -Be 'OA023'
                $result.Findings[0].Severity | Should -Be 'Warning'
                $result.Findings[0].Operation | Should -Be 'op'
                $result.Findings[0].Pointer | Should -BeExactly '/paths/~1items~1{id}/get/parameters/1'
                $result.Findings[0].Message | Should -Match "'extra'"
            }
        }

        It 'reports a template placeholder without a path parameter as OA024 (Error)' {
            InModuleScope tcs.openapi -Parameters @{ Convert = $script:convertPath } {
                param($Convert)
                $result = & $Convert '/items/{id}/{sub}' '{"parameters":[{"name":"id","in":"path"}],"get":{"parameters":[{"name":"sub","in":"query"}]}}'
                $result.Findings.Count | Should -Be 1
                $result.Findings[0].Code | Should -Be 'OA024'
                $result.Findings[0].Severity | Should -Be 'Error'
                $result.Findings[0].Pointer | Should -BeExactly '/paths/~1items~1{id}~1{sub}'
                $result.Findings[0].Message | Should -Match '\{sub\}'
            }
        }

        It 'compares placeholder and parameter names case-sensitively' {
            InModuleScope tcs.openapi -Parameters @{ Convert = $script:convertPath } {
                param($Convert)
                $result = & $Convert '/items/{Id}' '{"get":{"parameters":[{"name":"id","in":"path"}]}}'
                @($result.Findings.Code | Sort-Object) | Should -Be @('OA023', 'OA024')
            }
        }
    }
}
