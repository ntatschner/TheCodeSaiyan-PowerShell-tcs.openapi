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

Describe 'Get-OpenApiContextStore' {
    It 'returns the same module-scope hashtable every time' {
        InModuleScope -ModuleName tcs.openapi {
            $store = Get-OpenApiContextStore
            $store | Should -BeOfType ([hashtable])
            $store['Probe'] = 1
            (Get-OpenApiContextStore)['Probe'] | Should -Be 1
            $store.Remove('Probe')
        }
    }
}
