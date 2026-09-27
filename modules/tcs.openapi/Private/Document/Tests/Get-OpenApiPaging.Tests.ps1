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
}
