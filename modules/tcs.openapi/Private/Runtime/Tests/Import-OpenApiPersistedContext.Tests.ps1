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

Describe 'Import-OpenApiPersistedContext' {
    It 'returns $null when nothing is saved' {
        InModuleScope -ModuleName tcs.openapi {
            Import-OpenApiPersistedContext -Service 'NeverSaved' | Should -BeNullOrEmpty
        }
    }

    It 'loads the settings and secrets written by Save-OpenApiContextSetting' {
        InModuleScope -ModuleName tcs.openapi {
            $secret = (New-Object -TypeName System.Net.NetworkCredential -ArgumentList '', 'key-1').SecurePassword
            $credential = New-Object System.Management.Automation.PSCredential -ArgumentList 'u', ((New-Object -TypeName System.Net.NetworkCredential -ArgumentList '', 'pw').SecurePassword)
            $context = New-OpenApiContext -Service 'Saved' -BaseUri 'https://a/v2' -ApiKey $secret -Credential $credential -ClientId 'app' -TokenUri 'https://t' -Scope 's1' -Header @{ 'X-T' = '1' } -TimeoutSec 7 -MaxRetries 1 -Proxy 'http://p:1/' -SkipCertificateCheck $true
            Save-OpenApiContextSetting -Context $context
            $loaded = Import-OpenApiPersistedContext -Service 'Saved'
            $loaded.BaseUri | Should -Be 'https://a/v2'
            ConvertFrom-OpenApiSecureString -SecureString $loaded.ApiKey | Should -Be 'key-1'
            $loaded.Credential.UserName | Should -Be 'u'
            $loaded.Credential.GetNetworkCredential().Password | Should -Be 'pw'
            $loaded.BearerToken | Should -BeNullOrEmpty
            $loaded.ClientId | Should -Be 'app'
            $loaded.TokenUri | Should -Be 'https://t'
            $loaded.Scope | Should -Be @('s1')
            $loaded.Header['X-T'] | Should -Be '1'
            $loaded.TimeoutSec | Should -Be 7
            $loaded.MaxRetries | Should -Be 1
            $loaded.Proxy | Should -Be 'http://p:1/'
            $loaded.SkipCertificateCheck | Should -BeTrue
            $loaded.Persisted | Should -BeTrue
        }
    }

    It 'warns and continues when a saved secret cannot be read' {
        InModuleScope -ModuleName tcs.openapi {
            $context = New-OpenApiContext -Service 'Broken' -BaseUri 'https://a' -BearerToken ((New-Object -TypeName System.Net.NetworkCredential -ArgumentList '', 't').SecurePassword)
            Save-OpenApiContextSetting -Context $context
            Remove-ModuleSecret -ModuleName 'tcs.openapi' -Name 'Broken.BearerToken' -Confirm:$false
            $warnings = $null
            $loaded = Import-OpenApiPersistedContext -Service 'Broken' -WarningVariable warnings -WarningAction SilentlyContinue
            $loaded.BearerToken | Should -BeNullOrEmpty
            $warnings.Count | Should -Be 1
        }
    }
}
