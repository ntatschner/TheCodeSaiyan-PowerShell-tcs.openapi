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

Describe 'Get-OpenApiContextSettingPath' {
    It 'returns the settings file of a service and the folder without one' {
        InModuleScope -ModuleName tcs.openapi {
            $folder = Get-OpenApiContextSettingPath
            $folder | Should -Be (Join-Path -Path (Get-OpenApiConfigRoot) -ChildPath 'Contexts')
            Get-OpenApiContextSettingPath -Service 'Pet.Store' | Should -Be (Join-Path -Path $folder -ChildPath 'Pet.Store.json')
        }
    }

    It 'rejects names that could leave the folder' {
        InModuleScope -ModuleName tcs.openapi {
            { Get-OpenApiContextSettingPath -Service '../x' } | Should -Throw -ExceptionType ([System.ArgumentException])
        }
    }
}
