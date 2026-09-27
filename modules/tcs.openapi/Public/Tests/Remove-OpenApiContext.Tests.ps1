BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path $PSScriptRoot -Parent | Split-Path -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    # Windows PowerShell 5.1 does not load System.Net.Http by default
    Add-Type -AssemblyName 'System.Net.Http'
}

AfterAll {
    Remove-Module -Name tcs.openapi -Force -ErrorAction SilentlyContinue
}

Describe 'Remove-OpenApiContext' {
    It 'clears the session context and its cached client and tokens' {
        Set-OpenApiContext -Service 'Temp' -BaseUri 'https://a'
        InModuleScope -ModuleName tcs.openapi {
            $null = Get-OpenApiHttpClient -Context (Resolve-OpenApiContext -Service 'Temp')
            (Get-OpenApiModuleState -Name 'TcsOpenApiTokenCache')['Temp|https://t|id|'] = 1
        }
        Remove-OpenApiContext -Service 'Temp' -Confirm:$false
        InModuleScope -ModuleName tcs.openapi {
            (Get-OpenApiContextStore).ContainsKey('Temp') | Should -BeFalse
            (Get-OpenApiModuleState -Name 'TcsOpenApiHttpClients').ContainsKey('Temp') | Should -BeFalse
            (Get-OpenApiModuleState -Name 'TcsOpenApiTokenCache').Count | Should -Be 0
        }
    }

    It 'keeps the saved context without -Persisted, so it loads again' {
        Set-OpenApiContext -Service 'Kept' -BaseUri 'https://kept' -Persist
        Remove-OpenApiContext -Service 'Kept' -Confirm:$false
        (Get-OpenApiContext -Service 'Kept').BaseUri | Should -Be 'https://kept'
    }

    It 'deletes saved settings and secrets with -Persisted' {
        Set-OpenApiContext -Service 'Wiped' -BaseUri 'https://w' -ApiKey ((New-Object -TypeName System.Net.NetworkCredential -ArgumentList '', 'k').SecurePassword) -Persist
        Remove-OpenApiContext -Service 'Wiped' -Persisted -Confirm:$false
        Test-Path -LiteralPath (Join-Path -Path $env:TCS_CONFIG_ROOT -ChildPath 'tcs.openapi/Contexts/Wiped.json') | Should -BeFalse
        { Get-ModuleSecret -ModuleName 'tcs.openapi' -Name 'Wiped.ApiKey' -ErrorAction Stop } | Should -Throw
        { Get-OpenApiContext -Service 'Wiped' -ErrorAction Stop } | Should -Throw
    }

    It 'deletes a saved context that is not loaded with -Persisted' {
        Set-OpenApiContext -Service 'Cold' -BaseUri 'https://c' -Persist
        InModuleScope -ModuleName tcs.openapi {
            (Get-OpenApiContextStore).Remove('Cold')
        }
        Remove-OpenApiContext -Service 'Cold' -Persisted -Confirm:$false
        Test-Path -LiteralPath (Join-Path -Path $env:TCS_CONFIG_ROOT -ChildPath 'tcs.openapi/Contexts/Cold.json') | Should -BeFalse
    }

    It 'changes nothing with -WhatIf' {
        Set-OpenApiContext -Service 'Stay' -BaseUri 'https://s'
        Remove-OpenApiContext -Service 'Stay' -WhatIf
        (Get-OpenApiContext -Service 'Stay').BaseUri | Should -Be 'https://s'
    }

    It 'writes an error for an unknown service' {
        { Remove-OpenApiContext -Service 'Unknown' -Confirm:$false -ErrorAction Stop } | Should -Throw -ErrorId 'OpenApi.ContextNotFound*'
    }
}
