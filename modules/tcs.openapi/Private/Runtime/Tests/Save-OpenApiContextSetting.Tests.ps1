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

Describe 'Save-OpenApiContextSetting' {
    It 'writes settings as JSON without secrets and the secrets with tcs.core' {
        InModuleScope -ModuleName tcs.openapi {
            $context = Build-OpenApiContext -Service 'Disk' -BaseUri 'https://a' -BearerToken (ConvertTo-SecureString -String 'very-secret' -AsPlainText -Force) -ClientId 'app'
            Save-OpenApiContextSetting -Context $context
            $path = Get-OpenApiContextSettingPath -Service 'Disk'
            $json = [System.IO.File]::ReadAllText($path)
            $json | Should -Not -Match 'very-secret'
            $settings = $json | ConvertFrom-Json
            $settings.BaseUri | Should -Be 'https://a'
            $settings.ClientId | Should -Be 'app'
            @($settings.Secrets) | Should -Be @('BearerToken')
            $saved = Get-ModuleSecret -ModuleName 'tcs.openapi' -Name 'Disk.BearerToken'
            ConvertFrom-OpenApiSecureString -SecureString $saved | Should -Be 'very-secret'
        }
    }

    It 'removes secrets that the new context no longer has' {
        InModuleScope -ModuleName tcs.openapi {
            Save-OpenApiContextSetting -Context (Build-OpenApiContext -Service 'Swap' -BaseUri 'https://a' -ApiKey (ConvertTo-SecureString -String 'k' -AsPlainText -Force))
            Save-OpenApiContextSetting -Context (Build-OpenApiContext -Service 'Swap' -BaseUri 'https://a')
            { Get-ModuleSecret -ModuleName 'tcs.openapi' -Name 'Swap.ApiKey' -ErrorAction Stop } | Should -Throw
        }
    }
}
