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

Describe 'Get-OpenApiContext' {
    BeforeAll {
        $secret = (New-Object -TypeName System.Net.NetworkCredential -ArgumentList '', 'top-secret').SecurePassword
        $credential = New-Object System.Management.Automation.PSCredential -ArgumentList 'alice', $secret
        Set-OpenApiContext -Service 'Alpha' -BaseUri 'https://alpha' -ApiKey $secret -Credential $credential -BearerToken $secret -ClientId 'app' -ClientSecret $secret -Header @{ Authorization = 'x'; 'X-Plain' = 'p' }
        Set-OpenApiContext -Service 'Beta' -BaseUri 'https://beta'
        Set-OpenApiContext -Service 'Gamma' -BaseUri 'https://gamma' -Persist
        InModuleScope -ModuleName tcs.openapi {
            (Get-OpenApiContextStore).Remove('Gamma')
        }
    }

    It 'returns one context with every secret masked' {
        $view = Get-OpenApiContext -Service 'Alpha'
        $view.ApiKey | Should -Be '********'
        $view.BearerToken | Should -Be '********'
        $view.ClientSecret | Should -Be '********'
        $view.Credential | Should -Be 'alice / ********'
        $view.Header['Authorization'] | Should -Be '********'
        $view.Header['X-Plain'] | Should -Be 'p'
        ($view | Out-String) + ($view | ConvertTo-Json -Depth 5) | Should -Not -Match 'top-secret'
    }

    It 'lists every context, including saved ones not loaded yet, sorted by name' {
        @(Get-OpenApiContext).Service | Should -Be @('Alpha', 'Beta', 'Gamma')
        (Get-OpenApiContext -Service 'Gamma').Persisted | Should -BeTrue
    }

    It 'supports wildcards' {
        @(Get-OpenApiContext -Service '*a*').Service | Should -Be @('Alpha', 'Beta', 'Gamma')
        @(Get-OpenApiContext -Service 'B*').Service | Should -Be @('Beta')
        @(Get-OpenApiContext -Service 'Z*').Count | Should -Be 0
    }

    It 'writes an error for an unknown service' {
        { Get-OpenApiContext -Service 'Nope' -ErrorAction Stop } | Should -Throw -ErrorId 'OpenApi.ContextNotFound*'
    }
}
