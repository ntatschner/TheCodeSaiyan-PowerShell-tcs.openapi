BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../../tcs.openapi.psd1') -Force
}

Describe 'ConvertTo-OpenApiParameter' {
    BeforeAll {
        $script:convert = InModuleScope tcs.openapi {
            {
                param([string]$Json)
                $context = Get-OpenApiNormalizationContext -Root (ConvertFrom-OpenApiJson -Text '{}') -SourceVersion '3.0.3'
                ConvertTo-OpenApiParameter -Context $context -Node (ConvertFrom-OpenApiJson -Text $Json) -Pointer '/p'
            }
        }
    }

    It 'has the documented properties' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $parameter = & $Convert '{"name":"q","in":"query","description":"d","deprecated":true,"example":"ex","schema":{"type":"string"}}'
            $parameter.PSObject.TypeNames | Should -Contain 'Tcs.OpenApi.Parameter'
            @($parameter.PSObject.Properties.Name) | Should -Be @('Name', 'In', 'Required', 'Description', 'Deprecated', 'Schema', 'Style', 'Explode', 'AllowReserved', 'Example')
            $parameter.Name | Should -Be 'q'
            $parameter.Description | Should -Be 'd'
            $parameter.Deprecated | Should -BeTrue
            $parameter.Example | Should -Be 'ex'
            $parameter.Schema.Type | Should -Be 'string'
            $parameter.Required | Should -BeFalse
        }
    }

    It 'defaults style and explode for <In>' -TestCases @(
        @{ In = 'path'; Style = 'simple'; Explode = $false }
        @{ In = 'header'; Style = 'simple'; Explode = $false }
        @{ In = 'query'; Style = 'form'; Explode = $true }
        @{ In = 'cookie'; Style = 'form'; Explode = $true }
    ) {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert; In = $In; Style = $Style; Explode = $Explode } {
            param($Convert, $In, $Style, $Explode)
            $parameter = & $Convert ('{"name":"p","in":"' + $In + '","schema":{"type":"string"}}')
            $parameter.Style | Should -Be $Style
            $parameter.Explode | Should -Be $Explode
        }
    }

    It 'derives explode from an explicit style and keeps an explicit explode' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            (& $Convert '{"name":"p","in":"query","style":"pipeDelimited"}').Explode | Should -BeFalse
            (& $Convert '{"name":"p","in":"query","style":"form","explode":false}').Explode | Should -BeFalse
            (& $Convert '{"name":"p","in":"query","style":"deepObject","explode":true}').Explode | Should -BeTrue
        }
    }

    It 'makes path parameters required' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            (& $Convert '{"name":"id","in":"path","schema":{"type":"string"}}').Required | Should -BeTrue
        }
    }

    It 'keeps allowReserved' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            (& $Convert '{"name":"p","in":"query","allowReserved":true}').AllowReserved | Should -BeTrue
        }
    }

    It 'uses the schema of the first content media type' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            (& $Convert '{"name":"p","in":"query","content":{"application/json":{"schema":{"type":"object"}}}}').Schema.Type | Should -Be 'object'
        }
    }

    It 'takes the example from examples, then from the schema' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            (& $Convert '{"name":"p","in":"query","examples":{"one":{"value":"v1"}}}').Example | Should -Be 'v1'
            (& $Convert '{"name":"p","in":"query","schema":{"type":"string","example":"s"}}').Example | Should -Be 's'
        }
    }
}
