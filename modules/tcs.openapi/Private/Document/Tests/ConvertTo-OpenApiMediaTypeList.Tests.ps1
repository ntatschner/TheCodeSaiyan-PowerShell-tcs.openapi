BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../../tcs.openapi.psd1') -Force
}

Describe 'ConvertTo-OpenApiMediaTypeList' {
    BeforeAll {
        $script:convert = InModuleScope tcs.openapi {
            {
                param([string]$Json)
                $context = Get-OpenApiNormalizationContext -Root (ConvertFrom-OpenApiJson -Text '{}')
                ConvertTo-OpenApiMediaTypeList -Context $context -Content (ConvertFrom-OpenApiJson -Text $Json) -Pointer '/c'
            }
        }
    }

    It 'orders application/json first, then other JSON types, then the rest in document order' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $list = & $Convert '{"application/xml":{},"text/plain":{},"application/problem+json":{},"application/json; charset=utf-8":{},"text/json":{},"application/json":{}}'
            @($list.ContentType) | Should -Be @('application/json; charset=utf-8', 'application/json', 'application/problem+json', 'text/json', 'application/xml', 'text/plain')
        }
    }

    It 'normalises schemas and encodings' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $list = & $Convert '{"multipart/form-data":{"schema":{"type":"object"},"encoding":{"file":{"contentType":"image/png","style":"form","explode":false,"allowReserved":true},"meta":{"contentType":"application/json"}}}}'
            $list[0].PSObject.TypeNames | Should -Contain 'Tcs.OpenApi.MediaType'
            @($list[0].PSObject.Properties.Name) | Should -Be @('ContentType', 'Schema', 'Encoding')
            $list[0].Schema.Type | Should -Be 'object'
            $list[0].Encoding['file'].ContentType | Should -Be 'image/png'
            $list[0].Encoding['file'].Explode | Should -BeFalse
            $list[0].Encoding['file'].AllowReserved | Should -BeTrue
            $list[0].Encoding['meta'].Explode | Should -BeNullOrEmpty
        }
    }

    It 'returns an empty array for missing content, and a one-item array for one media type' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $context = Get-OpenApiNormalizationContext -Root $null
            $empty = ConvertTo-OpenApiMediaTypeList -Context $context -Content $null -Pointer ''
            , $empty | Should -BeOfType [object[]]
            $empty.Count | Should -Be 0
            $one = & $Convert '{"application/json":{}}'
            , $one | Should -BeOfType [object[]]
            $one[0].Schema | Should -BeNullOrEmpty
        }
    }
}
