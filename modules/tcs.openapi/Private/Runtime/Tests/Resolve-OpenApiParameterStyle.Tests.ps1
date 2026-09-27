BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    # Windows PowerShell 5.1 does not load System.Net.Http by default
    Add-Type -AssemblyName 'System.Net.Http'
}

AfterAll {
    Remove-Module -Name tcs.openapi -Force -ErrorAction SilentlyContinue
}

Describe 'Resolve-OpenApiParameterStyle' {
    It 'defaults <In> to <Style> with explode <Explode>' -ForEach @(
        @{ In = 'path'; Style = 'simple'; Explode = $false }
        @{ In = 'header'; Style = 'simple'; Explode = $false }
        @{ In = 'query'; Style = 'form'; Explode = $true }
        @{ In = 'cookie'; Style = 'form'; Explode = $true }
    ) {
        InModuleScope -ModuleName tcs.openapi -Parameters @{ In = $In; Style = $Style; Explode = $Explode } {
            $result = Resolve-OpenApiParameterStyle -In $In
            $result.Style | Should -Be $Style
            $result.Explode | Should -Be $Explode
        }
    }

    It 'keeps given values and defaults explode per style' {
        InModuleScope -ModuleName tcs.openapi {
            (Resolve-OpenApiParameterStyle -In 'query' -Style 'form' -Explode $false).Explode | Should -BeFalse
            (Resolve-OpenApiParameterStyle -In 'query' -Style 'spaceDelimited').Explode | Should -BeFalse
            (Resolve-OpenApiParameterStyle -In 'query' -Style 'deepObject').Explode | Should -BeTrue
            (Resolve-OpenApiParameterStyle -In 'path' -Style 'label' -Explode $true).Explode | Should -BeTrue
        }
    }
}
