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

Describe 'Get-OpenApiRedactedUri' {
    It 'masks secret query values and keeps the rest' {
        InModuleScope -ModuleName tcs.openapi {
            Get-OpenApiRedactedUri -Uri 'https://a/x?q=1&api_key=abc&sig=zz#frag' -SensitiveName 'sig' | Should -BeExactly 'https://a/x?q=1&api_key=********&sig=********#frag'
            Get-OpenApiRedactedUri -Uri 'https://a/x?access%5Ftoken=abc&flag' | Should -BeExactly 'https://a/x?access%5Ftoken=********&flag'
            Get-OpenApiRedactedUri -Uri 'https://a/x' | Should -BeExactly 'https://a/x'
        }
    }
}
