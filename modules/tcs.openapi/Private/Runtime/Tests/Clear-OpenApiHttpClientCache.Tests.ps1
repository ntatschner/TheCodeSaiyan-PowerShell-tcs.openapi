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

Describe 'Clear-OpenApiHttpClientCache' {
    It 'disposes the client of one service or of all' {
        InModuleScope -ModuleName tcs.openapi {
            $a = Get-OpenApiHttpClient -Context (New-OpenApiContext -Service 'A' -BaseUri 'https://a')
            $null = Get-OpenApiHttpClient -Context (New-OpenApiContext -Service 'B' -BaseUri 'https://b')
            Clear-OpenApiHttpClientCache -Service 'A'
            $cache = Get-OpenApiModuleState -Name 'TcsOpenApiHttpClients'
            $cache.ContainsKey('A') | Should -BeFalse
            $cache.ContainsKey('B') | Should -BeTrue
            { $a.CancelPendingRequests(); $a.GetAsync('http://127.0.0.1:1/').GetAwaiter().GetResult() } | Should -Throw
            Clear-OpenApiHttpClientCache
            $cache.Count | Should -Be 0
        }
    }

    It 'is called when the module is removed' {
        $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
        $client = InModuleScope -ModuleName tcs.openapi { Get-OpenApiHttpClient -Context (New-OpenApiContext -Service 'C' -BaseUri 'https://c') }
        Remove-Module -Name tcs.openapi -Force
        $failure = $null
        try {
            $null = $client.GetAsync('http://127.0.0.1:1/').GetAwaiter().GetResult()
        }
        catch {
            $failure = $_.Exception.InnerException
        }
        $failure | Should -BeOfType ([System.ObjectDisposedException])
        Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    }
}
