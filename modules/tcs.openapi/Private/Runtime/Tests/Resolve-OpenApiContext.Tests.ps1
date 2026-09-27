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

Describe 'Resolve-OpenApiContext' {
    It 'returns the context from the store' {
        InModuleScope -ModuleName tcs.openapi {
            $store = Get-OpenApiContextStore
            $store['Mem'] = Build-OpenApiContext -Service 'Mem' -BaseUri 'https://mem'
            (Resolve-OpenApiContext -Service 'Mem').BaseUri | Should -Be 'https://mem'
            $store.Remove('Mem')
        }
    }

    It 'loads a saved context once and keeps it in the store' {
        InModuleScope -ModuleName tcs.openapi {
            Save-OpenApiContextSetting -Context (Build-OpenApiContext -Service 'Lazy' -BaseUri 'https://lazy')
            (Get-OpenApiContextStore).ContainsKey('Lazy') | Should -BeFalse
            (Resolve-OpenApiContext -Service 'Lazy').BaseUri | Should -Be 'https://lazy'
            (Get-OpenApiContextStore).ContainsKey('Lazy') | Should -BeTrue
        }
    }

    It 'returns $null for an unknown service' {
        InModuleScope -ModuleName tcs.openapi {
            Resolve-OpenApiContext -Service 'Unknown' | Should -BeNullOrEmpty
        }
    }
}
