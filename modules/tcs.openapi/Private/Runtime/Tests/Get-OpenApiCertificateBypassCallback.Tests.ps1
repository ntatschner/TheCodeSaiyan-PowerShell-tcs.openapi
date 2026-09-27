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

Describe 'Get-OpenApiCertificateBypassCallback' {
    It 'returns a callback that accepts any certificate' {
        InModuleScope -ModuleName tcs.openapi {
            $callback = Get-OpenApiCertificateBypassCallback
            $callback | Should -Not -BeNullOrEmpty
            $callback.Invoke($null, $null, $null, [System.Net.Security.SslPolicyErrors]::RemoteCertificateNameMismatch) | Should -BeTrue
        }
    }
}
