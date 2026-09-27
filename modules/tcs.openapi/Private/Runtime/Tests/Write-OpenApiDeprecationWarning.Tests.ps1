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

Describe 'Write-OpenApiDeprecationWarning' {
    It 'warns once per service and operation' {
        InModuleScope -ModuleName tcs.openapi {
            $first = $null
            $second = $null
            $other = $null
            Write-OpenApiDeprecationWarning -Service 'S' -OperationId 'old' -WarningVariable first -WarningAction SilentlyContinue
            Write-OpenApiDeprecationWarning -Service 'S' -OperationId 'old' -WarningVariable second -WarningAction SilentlyContinue
            Write-OpenApiDeprecationWarning -Service 'T' -OperationId 'old' -WarningVariable other -WarningAction SilentlyContinue
            @($first).Count | Should -Be 1
            $first[0].Message | Should -Match "'old'.*'S'.*deprecated"
            @($second).Count | Should -Be 0
            @($other).Count | Should -Be 1
        }
    }
}
