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

Describe 'ConvertTo-OpenApiJsonText' {
    It 'writes compact JSON with explicit nulls' {
        InModuleScope -ModuleName tcs.openapi {
            ConvertTo-OpenApiJsonText -InputObject ([ordered]@{ a = $null; b = @('x'); c = $false }) | Should -BeExactly '{"a":null,"b":["x"],"c":false}'
            ConvertTo-OpenApiJsonText -InputObject $null | Should -BeExactly 'null'
            ConvertTo-OpenApiJsonText -InputObject @(1) | Should -BeExactly '[1]'
        }
    }
}
