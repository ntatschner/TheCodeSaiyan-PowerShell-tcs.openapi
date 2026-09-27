BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
}

AfterAll {
    Remove-Module -Name tcs.openapi -Force -ErrorAction SilentlyContinue
}

Describe 'ConvertFrom-OpenApiSecureString' {
    It 'decodes a SecureString and returns $null for $null' {
        InModuleScope -ModuleName tcs.openapi {
            ConvertFrom-OpenApiSecureString -SecureString (ConvertTo-SecureString -String 'abc' -AsPlainText -Force) | Should -BeExactly 'abc'
            ConvertFrom-OpenApiSecureString -SecureString $null | Should -BeNullOrEmpty
        }
    }
}
