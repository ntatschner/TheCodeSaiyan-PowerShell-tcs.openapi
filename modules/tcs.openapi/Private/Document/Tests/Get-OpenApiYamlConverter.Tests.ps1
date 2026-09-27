BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../../tcs.openapi.psd1') -Force
}

Describe 'Get-OpenApiYamlConverter' {
    It 'returns ConvertFrom-Yaml when it is available' {
        function global:ConvertFrom-Yaml {
            param([string]$Yaml)
            $Yaml
        }
        try {
            $command = InModuleScope tcs.openapi { Get-OpenApiYamlConverter }
            $command.Name | Should -Be 'ConvertFrom-Yaml'
        }
        finally {
            Remove-Item -Path 'Function:\ConvertFrom-Yaml' -ErrorAction SilentlyContinue
        }
    }

    It 'returns nothing when ConvertFrom-Yaml is not available' {
        InModuleScope tcs.openapi {
            Mock Get-Command { }
            Get-OpenApiYamlConverter | Should -BeNullOrEmpty
        }
    }
}
