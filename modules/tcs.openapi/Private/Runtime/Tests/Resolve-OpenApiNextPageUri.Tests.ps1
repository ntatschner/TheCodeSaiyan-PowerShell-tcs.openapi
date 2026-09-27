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

Describe 'Resolve-OpenApiNextPageUri' {
    It 'resolves relative links against the current URL' {
        InModuleScope -ModuleName tcs.openapi {
            Resolve-OpenApiNextPageUri -Link '?page=2' -CurrentUri 'https://api.example.com/v1/items?page=1' -OriginUri 'https://api.example.com/v1/items' | Should -Be 'https://api.example.com/v1/items?page=2'
            Resolve-OpenApiNextPageUri -Link '/v1/items/next' -CurrentUri 'https://api.example.com/v1/items' -OriginUri 'https://api.example.com/v1/items' | Should -Be 'https://api.example.com/v1/items/next'
            Resolve-OpenApiNextPageUri -Link 'https://api.example.com/v1/x' -CurrentUri 'https://api.example.com/v1' -OriginUri 'https://api.example.com/v1' | Should -Be 'https://api.example.com/v1/x'
        }
    }

    It 'refuses another host, scheme or port with a warning' {
        InModuleScope -ModuleName tcs.openapi {
            foreach ($link in 'https://evil.example.com/x', 'http://api.example.com/x', 'https://api.example.com:8443/x') {
                $warnings = $null
                Resolve-OpenApiNextPageUri -Link $link -CurrentUri 'https://api.example.com/v1' -OriginUri 'https://api.example.com/v1' -WarningVariable warnings -WarningAction SilentlyContinue | Should -BeNullOrEmpty
                $warnings.Count | Should -Be 1
            }
        }
    }

    It 'returns $null for an empty link' {
        InModuleScope -ModuleName tcs.openapi {
            Resolve-OpenApiNextPageUri -Link '' -CurrentUri 'https://a/' -OriginUri 'https://a/' | Should -BeNullOrEmpty
        }
    }
}
