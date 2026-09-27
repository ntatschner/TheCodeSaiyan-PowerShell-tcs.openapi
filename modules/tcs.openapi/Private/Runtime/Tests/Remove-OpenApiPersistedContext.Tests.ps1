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

Describe 'Remove-OpenApiPersistedContext' {
    It 'deletes the settings file and the saved secrets' {
        InModuleScope -ModuleName tcs.openapi {
            $context = New-OpenApiContext -Service 'Gone' -BaseUri 'https://a' -ApiKey (ConvertTo-SecureString -String 'k' -AsPlainText -Force)
            Save-OpenApiContextSetting -Context $context
            Remove-OpenApiPersistedContext -Service 'Gone' -Confirm:$false | Should -BeTrue
            Test-Path -LiteralPath (Get-OpenApiContextSettingPath -Service 'Gone') | Should -BeFalse
            { Get-ModuleSecret -ModuleName 'tcs.openapi' -Name 'Gone.ApiKey' -ErrorAction Stop } | Should -Throw
            Remove-OpenApiPersistedContext -Service 'Gone' -Confirm:$false | Should -BeFalse
        }
    }

    It 'changes nothing with -WhatIf' {
        InModuleScope -ModuleName tcs.openapi {
            Save-OpenApiContextSetting -Context (New-OpenApiContext -Service 'Kept' -BaseUri 'https://a')
            Remove-OpenApiPersistedContext -Service 'Kept' -WhatIf | Should -BeFalse
            Test-Path -LiteralPath (Get-OpenApiContextSettingPath -Service 'Kept') | Should -BeTrue
        }
    }
}
