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

Describe 'Set-OpenApiContext' {
    BeforeEach {
        InModuleScope -ModuleName tcs.openapi {
            (Get-OpenApiContextStore).Clear()
        }
    }

    It 'stores the context in the session and returns it redacted with -PassThru' {
        $key = (New-Object -TypeName System.Net.NetworkCredential -ArgumentList '', 'my-key').SecurePassword
        $view = Set-OpenApiContext -Service 'Pets' -BaseUri 'https://pets.example.com/v1/' -ApiKey $key -Header @{ 'X-Tenant' = 'a' } -TimeoutSec 30 -MaxRetries 5 -PassThru
        $view.PSObject.TypeNames[0] | Should -Be 'Tcs.OpenApi.Context'
        $view.BaseUri | Should -Be 'https://pets.example.com/v1'
        $view.ApiKey | Should -Be '********'
        $view.TimeoutSec | Should -Be 30
        $view.MaxRetries | Should -Be 5
        $view.Persisted | Should -BeFalse
        InModuleScope -ModuleName tcs.openapi {
            $context = (Get-OpenApiContextStore)['Pets']
            $context.ApiKey | Should -BeOfType ([System.Security.SecureString])
            ConvertFrom-OpenApiSecureString -SecureString $context.ApiKey | Should -Be 'my-key'
        }
    }

    It 'writes nothing without -PassThru' {
        Set-OpenApiContext -Service 'Pets' -BaseUri 'https://a' | Should -BeNullOrEmpty
    }

    It 'replaces an earlier context of the same service' {
        Set-OpenApiContext -Service 'Pets' -BaseUri 'https://a' -BearerToken ((New-Object -TypeName System.Net.NetworkCredential -ArgumentList '', 't').SecurePassword)
        Set-OpenApiContext -Service 'Pets' -BaseUri 'https://b'
        $view = Get-OpenApiContext -Service 'Pets'
        $view.BaseUri | Should -Be 'https://b'
        $view.BearerToken | Should -BeNullOrEmpty
    }

    It 'saves secrets with tcs.core and settings as JSON with -Persist' {
        $secret = (New-Object -TypeName System.Net.NetworkCredential -ArgumentList '', 'client-secret').SecurePassword
        Set-OpenApiContext -Service 'Saved' -BaseUri 'https://a' -ClientId 'app' -ClientSecret $secret -TokenUri 'https://login/token' -Scope 'x.read' -Persist
        $path = Join-Path -Path $env:TCS_CONFIG_ROOT -ChildPath 'tcs.openapi/Contexts/Saved.json'
        Test-Path -LiteralPath $path | Should -BeTrue
        Get-Content -LiteralPath $path -Raw | Should -Not -Match 'client-secret'
        $saved = Get-ModuleSecret -ModuleName 'tcs.openapi' -Name 'Saved.ClientSecret'
        (New-Object System.Net.NetworkCredential -ArgumentList '', $saved).Password | Should -Be 'client-secret'
    }

    It 'loads a persisted context lazily in a later session' {
        Set-OpenApiContext -Service 'Later' -BaseUri 'https://later' -BearerToken ((New-Object -TypeName System.Net.NetworkCredential -ArgumentList '', 'tok').SecurePassword) -Persist
        $ModuleRoot = Split-Path -Path $PSScriptRoot -Parent | Split-Path -Parent
        Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
        InModuleScope -ModuleName tcs.openapi {
            (Get-OpenApiContextStore).ContainsKey('Later') | Should -BeFalse
            $context = Resolve-OpenApiContext -Service 'Later'
            ConvertFrom-OpenApiSecureString -SecureString $context.BearerToken | Should -Be 'tok'
        }
    }

    It 'changes nothing with -WhatIf' {
        Set-OpenApiContext -Service 'WhatIf' -BaseUri 'https://a' -Persist -WhatIf
        InModuleScope -ModuleName tcs.openapi {
            (Get-OpenApiContextStore).ContainsKey('WhatIf') | Should -BeFalse
        }
        Test-Path -LiteralPath (Join-Path -Path $env:TCS_CONFIG_ROOT -ChildPath 'tcs.openapi/Contexts/WhatIf.json') | Should -BeFalse
    }

    It 'rejects <Case>' -ForEach @(
        @{ Case = 'a relative base URI'; Arguments = @{ Service = 'X'; BaseUri = 'relative/path' } }
        @{ Case = 'a non-http base URI'; Arguments = @{ Service = 'X'; BaseUri = 'ftp://a' } }
        @{ Case = 'a client ID without a secret'; Arguments = @{ Service = 'X'; BaseUri = 'https://a'; ClientId = 'id' } }
        @{ Case = 'an invalid service name'; Arguments = @{ Service = '../x'; BaseUri = 'https://a' } }
    ) {
        { Set-OpenApiContext @Arguments -ErrorAction Stop } | Should -Throw
    }

    It 'disposes the cached HTTP client of the service' {
        Set-OpenApiContext -Service 'Pets' -BaseUri 'https://a'
        $client = InModuleScope -ModuleName tcs.openapi { Get-OpenApiHttpClient -Context (Resolve-OpenApiContext -Service 'Pets') }
        Set-OpenApiContext -Service 'Pets' -BaseUri 'https://b'
        InModuleScope -ModuleName tcs.openapi -Parameters @{ Client = $client } {
            (Get-OpenApiModuleState -Name 'TcsOpenApiHttpClients').ContainsKey('Pets') | Should -BeFalse
        }
    }
}
