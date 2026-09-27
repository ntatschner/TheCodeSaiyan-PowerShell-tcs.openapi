BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../../tcs.openapi.psd1') -Force
}

Describe 'Get-OpenApiPaging' {
    BeforeAll {
        $script:paging = InModuleScope tcs.openapi {
            {
                param([string]$Operation)
                $context = Get-OpenApiNormalizationContext -Root $null
                $raw = ConvertFrom-OpenApiJson -Text $Operation
                $responses = ConvertTo-OpenApiResponseList -Context $context -Responses $raw['responses'] -Pointer ''
                Get-OpenApiPaging -Operation $raw -Responses $responses
            }
        }
    }

    It 'uses x-ms-pageable' {
        InModuleScope tcs.openapi -Parameters @{ Paging = $script:paging } {
            param($Paging)
            $result = & $Paging '{"x-ms-pageable":{"nextLinkName":"nextLink"},"responses":{}}'
            $result.Kind | Should -Be 'nextLink'
            $result.ItemsProperty | Should -Be 'value'
            $result.NextLinkProperty | Should -Be 'nextLink'
            (& $Paging '{"x-ms-pageable":{"nextLinkName":"@odata.nextLink","itemName":"items"}}').ItemsProperty | Should -Be 'items'
        }
    }

    It 'treats x-ms-pageable with a null nextLinkName as one page' {
        InModuleScope tcs.openapi -Parameters @{ Paging = $script:paging } {
            param($Paging)
            & $Paging '{"x-ms-pageable":{"nextLinkName":null},"responses":{"200":{"description":"","content":{"application/json":{"schema":{"properties":{"value":{"type":"array"},"nextLink":{"type":"string"}}}}}}}}' | Should -BeNullOrEmpty
        }
    }

    It 'detects one array property plus <Name>' -TestCases @(
        @{ Name = 'nextLink' }
        @{ Name = 'next' }
        @{ Name = '@odata.nextLink' }
        @{ Name = 'NextLink' }
    ) {
        InModuleScope tcs.openapi -Parameters @{ Paging = $script:paging; Name = $Name } {
            param($Paging, $Name)
            $result = & $Paging ('{"responses":{"200":{"description":"","content":{"application/json":{"schema":{"type":"object","properties":{"data":{"type":"array","items":{}},"total":{"type":"integer"},"' + $Name + '":{"type":"string"}}}}}}}}')
            $result.Kind | Should -Be 'nextLink'
            $result.ItemsProperty | Should -Be 'data'
            $result.NextLinkProperty | Should -BeExactly $Name
        }
    }

    It 'does not detect paging with two array properties or without a next link' {
        InModuleScope tcs.openapi -Parameters @{ Paging = $script:paging } {
            param($Paging)
            & $Paging '{"responses":{"200":{"description":"","content":{"application/json":{"schema":{"properties":{"a":{"type":"array"},"b":{"type":"array"},"nextLink":{"type":"string"}}}}}}}}' | Should -BeNullOrEmpty
            & $Paging '{"responses":{"200":{"description":"","content":{"application/json":{"schema":{"properties":{"a":{"type":"array"}}}}}}}}' | Should -BeNullOrEmpty
            & $Paging '{"responses":{"200":{"description":"","content":{"application/json":{"schema":{"properties":{"a":{"type":"array"},"nextLink":{"type":"integer"}}}}}}}}' | Should -BeNullOrEmpty
        }
    }

    It 'detects a Link header' {
        InModuleScope tcs.openapi -Parameters @{ Paging = $script:paging } {
            param($Paging)
            $array = & $Paging '{"responses":{"200":{"description":"","headers":{"link":{"schema":{"type":"string"}}},"content":{"application/json":{"schema":{"type":"array","items":{}}}}}}}'
            $array.Kind | Should -Be 'linkHeader'
            $array.ItemsProperty | Should -BeNullOrEmpty
            $array.NextLinkProperty | Should -BeNullOrEmpty
            $object = & $Paging '{"responses":{"200":{"description":"","headers":{"Link":{}},"content":{"application/json":{"schema":{"properties":{"items":{"type":"array"}}}}}}}}'
            $object.ItemsProperty | Should -Be 'items'
        }
    }

    It 'returns nothing for an operation without paging' {
        InModuleScope tcs.openapi -Parameters @{ Paging = $script:paging } {
            param($Paging)
            & $Paging '{"responses":{"204":{"description":""}}}' | Should -BeNullOrEmpty
        }
    }

    Context 'token paging' {
        BeforeAll {
            $script:tokenPaging = InModuleScope tcs.openapi {
                {
                    param([string]$Operation)
                    $context = Get-OpenApiNormalizationContext -Root $null
                    $raw = ConvertFrom-OpenApiJson -Text $Operation
                    $responses = ConvertTo-OpenApiResponseList -Context $context -Responses $raw['responses'] -Pointer ''
                    $parameters = @(foreach ($node in @($raw['parameters'])) {
                            if ($null -ne $node) {
                                ConvertTo-OpenApiParameter -Context $context -Node $node -Pointer ''
                            }
                        })
                    Get-OpenApiPaging -Operation $raw -Responses $responses -Parameters $parameters
                }
            }
            $script:tokenJson = {
                param([string]$Parameter, [string]$Property, [string]$Extra = '')
                '{"parameters":[{"name":"pageSize","in":"query"},{"name":"' + $Parameter + '","in":"query","schema":{"type":"string"}}],' +
                '"responses":{"200":{"description":"","content":{"application/json":{"schema":{"type":"object","properties":{"data":{"type":"array","items":{}},"traceId":{"type":"string"},"' + $Property + '":{"type":"string"}' + $Extra + '}}}}}}}'
            }
        }

        It 'detects query <Parameter> with response property <Property>' -TestCases @(
            @{ Parameter = 'nextToken'; Property = 'nextToken' }
            @{ Parameter = 'pageToken'; Property = 'nextPageToken' }
            @{ Parameter = 'next_token'; Property = 'next_token' }
            @{ Parameter = 'page_token'; Property = 'next_page_token' }
            @{ Parameter = 'cursor'; Property = 'next_cursor' }
            @{ Parameter = 'Cursor'; Property = 'nextCursor' }
            @{ Parameter = 'continuationToken'; Property = 'continuationToken' }
            @{ Parameter = 'continuation_token'; Property = 'continuation_token' }
            @{ Parameter = 'NEXTTOKEN'; Property = 'nextToken' }
        ) {
            InModuleScope tcs.openapi -Parameters @{ Paging = $script:tokenPaging; Json = (& $script:tokenJson $Parameter $Property) ; Parameter = $Parameter; Property = $Property } {
                param($Paging, $Json, $Parameter, $Property)
                $result = & $Paging $Json
                $result.PSObject.TypeNames | Should -Contain 'Tcs.OpenApi.Paging'
                $result.Kind | Should -Be 'token'
                $result.ItemsProperty | Should -Be 'data'
                $result.TokenParameter | Should -BeExactly $Parameter
                $result.TokenProperty | Should -BeExactly $Property
            }
        }

        It 'prefers the property named like the parameter' {
            InModuleScope tcs.openapi -Parameters @{ Paging = $script:tokenPaging; Json = (& $script:tokenJson 'cursor' 'nextToken' ',"cursor":{"type":"string"}') } {
                param($Paging, $Json)
                (& $Paging $Json).TokenProperty | Should -BeExactly 'cursor'
            }
        }

        It 'needs the query parameter, one array property and a string token property' {
            InModuleScope tcs.openapi -Parameters @{ Paging = $script:tokenPaging; Token = $script:tokenJson } {
                param($Paging, $Token)
                # No token query parameter
                & $Paging '{"responses":{"200":{"description":"","content":{"application/json":{"schema":{"properties":{"data":{"type":"array"},"nextToken":{"type":"string"}}}}}}}}' | Should -BeNullOrEmpty
                # The token parameter is a header
                & $Paging '{"parameters":[{"name":"nextToken","in":"header"}],"responses":{"200":{"description":"","content":{"application/json":{"schema":{"properties":{"data":{"type":"array"},"nextToken":{"type":"string"}}}}}}}}' | Should -BeNullOrEmpty
                # Two arrays, no token property, a numeric token
                & $Paging (& $Token 'nextToken' 'nextToken' ',"more":{"type":"array"}') | Should -BeNullOrEmpty
                & $Paging (& $Token 'nextToken' 'other') | Should -BeNullOrEmpty
                & $Paging ((& $Token 'nextToken' 'nextToken').Replace('"nextToken":{"type":"string"}', '"nextToken":{"type":"integer"}')) | Should -BeNullOrEmpty
            }
        }

        It 'keeps nextLink detection and x-ms-pageable ahead of token paging' {
            InModuleScope tcs.openapi -Parameters @{ Paging = $script:tokenPaging; Token = $script:tokenJson } {
                param($Paging, $Token)
                (& $Paging (& $Token 'nextToken' 'nextToken' ',"nextLink":{"type":"string"}')).Kind | Should -Be 'nextLink'
                $pageable = (& $Token 'nextToken' 'nextToken').Replace('{"parameters"', '{"x-ms-pageable":{"nextLinkName":"next","itemName":"data"},"parameters"')
                $result = & $Paging $pageable
                $result.Kind | Should -Be 'nextLink'
                $result.NextLinkProperty | Should -Be 'next'
            }
        }
    }
}
