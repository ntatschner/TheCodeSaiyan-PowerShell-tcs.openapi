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

Describe 'Get-OpenApiModuleState' {
    It 'creates the named hashtable once and returns it afterwards' {
        InModuleScope -ModuleName tcs.openapi {
            $state = Get-OpenApiModuleState -Name 'TcsOpenApiTokenCache'
            $state['x'] = 1
            (Get-OpenApiModuleState -Name 'TcsOpenApiTokenCache')['x'] | Should -Be 1
            $state.Remove('x')
        }
    }

    It 'keeps the hashtable it creates under $WhatIfPreference' {
        InModuleScope -ModuleName tcs.openapi {
            Remove-Variable -Name 'TcsOpenApiDeprecationWarned' -Scope Script -ErrorAction SilentlyContinue
            $WhatIfPreference = $true
            $state = Get-OpenApiModuleState -Name 'TcsOpenApiDeprecationWarned'
            $state['x'] = 1
            (Get-OpenApiModuleState -Name 'TcsOpenApiDeprecationWarned')['x'] | Should -Be 1
            $state.Remove('x')
        }
    }

    It 'writes no error when the variable does not exist yet' {
        InModuleScope -ModuleName tcs.openapi {
            Remove-Variable -Name 'TcsOpenApiDeprecationWarned' -Scope Script -ErrorAction SilentlyContinue
            $errors = $null
            $null = Get-OpenApiModuleState -Name 'TcsOpenApiDeprecationWarned' -ErrorVariable errors
            @($errors).Count | Should -Be 0
        }
    }
}
