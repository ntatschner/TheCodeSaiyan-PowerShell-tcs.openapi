BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../../tcs.openapi.psd1') -Force
}

Describe 'ConvertFrom-OpenApiText' {
    It 'detects JSON from the first character' {
        InModuleScope tcs.openapi {
            Mock Get-OpenApiYamlConverter { }
            $node = ConvertFrom-OpenApiText -Text "  `n {`"openapi`":`"3.0.0`"}"
            $node['openapi'] | Should -Be '3.0.0'
            Should -Invoke Get-OpenApiYamlConverter -Times 0
        }
    }

    It 'strips a leading byte order mark' {
        InModuleScope tcs.openapi {
            $node = ConvertFrom-OpenApiText -Text ([char]0xFEFF + '{"a":1}')
            $node['a'] | Should -Be 1
        }
    }

    It 'throws for empty text' {
        InModuleScope tcs.openapi {
            { ConvertFrom-OpenApiText -Text '  ' } | Should -Throw -ExpectedMessage 'The document is empty.'
        }
    }

    It 'throws OpenApi.YamlNotSupported for YAML when powershell-yaml is missing' {
        InModuleScope tcs.openapi {
            Mock Get-OpenApiYamlConverter { }
            $thrown = $null
            try {
                ConvertFrom-OpenApiText -Text "openapi: 3.0.0`ninfo: {}"
            }
            catch {
                $thrown = $_
            }
            $thrown | Should -Not -BeNullOrEmpty
            $thrown.FullyQualifiedErrorId | Should -BeLike 'OpenApi.YamlNotSupported*'
            $thrown.Exception.Message | Should -BeLike '*powershell-yaml*'
        }
    }

    It 'uses ConvertFrom-Yaml (with -Ordered when supported) and converts its output' {
        function global:ConvertFrom-Yaml {
            param([string]$Yaml, [switch]$Ordered)
            $result = [ordered]@{ yamlText = $Yaml; ordered = [bool]$Ordered; responses = @{ 200 = 'ok' } }
            $result
        }
        try {
            $node = InModuleScope tcs.openapi { ConvertFrom-OpenApiText -Text 'openapi: 3.0.0' -Format Yaml }
            $node['yamlText'] | Should -Be 'openapi: 3.0.0'
            $node['ordered'] | Should -BeTrue
            $node['responses']['200'] | Should -Be 'ok'
        }
        finally {
            Remove-Item -Path 'Function:\ConvertFrom-Yaml' -ErrorAction SilentlyContinue
        }
    }

    It 'wraps YAML parser errors' {
        InModuleScope tcs.openapi {
            Mock Get-OpenApiYamlConverter { { param($Yaml) throw 'bad indentation' } }
            { ConvertFrom-OpenApiText -Text 'a: : b' } | Should -Throw -ExpectedMessage 'The document is not valid YAML: bad indentation'
        }
    }
}
