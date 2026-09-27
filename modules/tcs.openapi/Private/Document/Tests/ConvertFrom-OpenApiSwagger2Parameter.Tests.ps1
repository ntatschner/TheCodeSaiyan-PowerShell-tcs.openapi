BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../../tcs.openapi.psd1') -Force
}

Describe 'ConvertFrom-OpenApiSwagger2Parameter' {
    It 'moves the type keywords into schema' {
        InModuleScope tcs.openapi {
            $parameter = ConvertFrom-OpenApiSwagger2Parameter -Node (ConvertFrom-OpenApiJson -Text '{"name":"limit","in":"query","description":"d","required":true,"type":"integer","default":20,"x-ms-client-name":"top"}')
            $parameter['name'] | Should -Be 'limit'
            $parameter['in'] | Should -Be 'query'
            $parameter['description'] | Should -Be 'd'
            $parameter['required'] | Should -BeTrue
            $parameter['schema']['type'] | Should -Be 'integer'
            $parameter['schema']['default'] | Should -Be 20
            $parameter['x-ms-client-name'] | Should -Be 'top'
            $parameter.Contains('type') | Should -BeFalse
            $parameter.Contains('style') | Should -BeFalse
        }
    }

    It 'maps collectionFormat <Format> in <In> to <Style>/<Explode>' -TestCases @(
        @{ Format = 'csv'; In = 'query'; Style = 'form'; Explode = $false }
        @{ Format = ''; In = 'query'; Style = 'form'; Explode = $false }
        @{ Format = 'ssv'; In = 'query'; Style = 'spaceDelimited'; Explode = $false }
        @{ Format = 'pipes'; In = 'query'; Style = 'pipeDelimited'; Explode = $false }
        @{ Format = 'multi'; In = 'query'; Style = 'form'; Explode = $true }
        @{ Format = 'tsv'; In = 'query'; Style = 'form'; Explode = $false }
        @{ Format = 'csv'; In = 'path'; Style = 'simple'; Explode = $false }
        @{ Format = 'csv'; In = 'header'; Style = 'simple'; Explode = $false }
    ) {
        InModuleScope tcs.openapi -Parameters @{ Format = $Format; In = $In; Style = $Style; Explode = $Explode } {
            param($Format, $In, $Style, $Explode)
            $json = '{"name":"p","in":"' + $In + '","type":"array","items":{"type":"string"}'
            if ($Format) {
                $json += ',"collectionFormat":"' + $Format + '"'
            }
            $parameter = ConvertFrom-OpenApiSwagger2Parameter -Node (ConvertFrom-OpenApiJson -Text ($json + '}'))
            $parameter['style'] | Should -Be $Style
            $parameter['explode'] | Should -Be $Explode
            $parameter['schema']['items']['type'] | Should -Be 'string'
        }
    }
}
