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

Describe 'Clear-OpenApiTokenCache' {
    It 'forgets the tokens of one service or of all' {
        InModuleScope -ModuleName tcs.openapi {
            $cache = Get-OpenApiModuleState -Name 'TcsOpenApiTokenCache'
            $cache['A|https://t|id|'] = 1
            $cache['AB|https://t|id|'] = 2
            Clear-OpenApiTokenCache -Service 'A'
            $cache.ContainsKey('A|https://t|id|') | Should -BeFalse
            $cache.ContainsKey('AB|https://t|id|') | Should -BeTrue
            Clear-OpenApiTokenCache
            $cache.Count | Should -Be 0
        }
    }
}
