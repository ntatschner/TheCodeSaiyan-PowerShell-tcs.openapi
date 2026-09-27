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

Describe 'Test-OpenApiMember' {
    It 'tests keys and properties, including ones whose value is $null' {
        InModuleScope -ModuleName tcs.openapi {
            Test-OpenApiMember -InputObject @{ a = $null } -Name 'A' | Should -BeTrue
            Test-OpenApiMember -InputObject ([pscustomobject]@{ a = $null }) -Name 'a' | Should -BeTrue
            Test-OpenApiMember -InputObject @{ a = 1 } -Name 'b' | Should -BeFalse
            Test-OpenApiMember -InputObject $null -Name 'a' | Should -BeFalse
        }
    }
}
