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

Describe 'ConvertTo-OpenApiContextView' {
    It 'shows every secret as ********' {
        InModuleScope -ModuleName tcs.openapi {
            $secret = ConvertTo-SecureString -String 'plain-secret' -AsPlainText -Force
            $credential = New-Object System.Management.Automation.PSCredential -ArgumentList 'user', $secret
            $context = Build-OpenApiContext -Service 'S' -BaseUri 'https://a' -ApiKey $secret -BearerToken $secret -ClientId 'app' -ClientSecret $secret -Credential $credential -ProxyCredential $credential -Header @{ 'X-Api-Token' = 'tok'; 'X-Tenant' = 't1' }
            $view = ConvertTo-OpenApiContextView -Context $context
            $view.PSObject.TypeNames[0] | Should -Be 'Tcs.OpenApi.Context'
            $view.ApiKey | Should -Be '********'
            $view.BearerToken | Should -Be '********'
            $view.ClientSecret | Should -Be '********'
            $view.Credential | Should -Be 'user / ********'
            $view.ProxyCredential | Should -Be 'user / ********'
            $view.Header['X-Api-Token'] | Should -Be '********'
            $view.Header['X-Tenant'] | Should -Be 't1'
            $view.ClientId | Should -Be 'app'
            ($view | ConvertTo-Json -Depth 5) | Should -Not -Match 'plain-secret'
        }
    }

    It 'shows missing secrets as empty' {
        InModuleScope -ModuleName tcs.openapi {
            $view = ConvertTo-OpenApiContextView -Context (Build-OpenApiContext -Service 'S' -BaseUri 'https://a')
            $view.ApiKey | Should -BeNullOrEmpty
            $view.Credential | Should -BeNullOrEmpty
        }
    }
}
