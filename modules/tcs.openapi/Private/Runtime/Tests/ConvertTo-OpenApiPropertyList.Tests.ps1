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

Describe 'ConvertTo-OpenApiPropertyList' {
    It 'lists dictionary entries and object properties in order' {
        InModuleScope -ModuleName tcs.openapi {
            @(ConvertTo-OpenApiPropertyList -InputObject ([ordered]@{ b = 1; a = 2 })).Name | Should -Be @('b', 'a')
            $list = @(ConvertTo-OpenApiPropertyList -InputObject ([pscustomobject]@{ x = 1; y = $null }))
            $list.Name | Should -Be @('x', 'y')
            $list[1].Value | Should -BeNullOrEmpty
            @(ConvertTo-OpenApiPropertyList -InputObject $null).Count | Should -Be 0
        }
    }
}
