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

Describe 'Get-OpenApiConfigRoot' {
    It 'uses TCS_CONFIG_ROOT when it is set' {
        InModuleScope -ModuleName tcs.openapi {
            Get-OpenApiConfigRoot | Should -Be (Join-Path -Path $env:TCS_CONFIG_ROOT -ChildPath 'tcs.openapi')
        }
    }

    It 'falls back to <ApplicationData>/PowerShell/Config' {
        $saved = $env:TCS_CONFIG_ROOT
        try {
            $env:TCS_CONFIG_ROOT = ''
            InModuleScope -ModuleName tcs.openapi {
                Get-OpenApiConfigRoot | Should -Match 'PowerShell[\\/]Config[\\/]tcs\.openapi$'
            }
        }
        finally {
            $env:TCS_CONFIG_ROOT = $saved
        }
    }
}
