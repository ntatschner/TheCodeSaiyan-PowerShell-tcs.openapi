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

Describe 'Build-OpenApiHttpClientHandler' {
    It 'enables decompression and disables the cookie container' {
        InModuleScope -ModuleName tcs.openapi {
            $handler = Build-OpenApiHttpClientHandler -Context (Build-OpenApiContext -Service 'S' -BaseUri 'https://a')
            $handler.AutomaticDecompression.HasFlag([System.Net.DecompressionMethods]::GZip) | Should -BeTrue
            $handler.AutomaticDecompression.HasFlag([System.Net.DecompressionMethods]::Deflate) | Should -BeTrue
            $handler.UseCookies | Should -BeFalse
            $handler.ServerCertificateCustomValidationCallback | Should -BeNullOrEmpty
            $handler.Dispose()
        }
    }

    It 'sets the proxy with its credential' {
        InModuleScope -ModuleName tcs.openapi {
            $credential = New-Object System.Management.Automation.PSCredential -ArgumentList 'proxyuser', (ConvertTo-SecureString -String 'pw' -AsPlainText -Force)
            $handler = Build-OpenApiHttpClientHandler -Context (Build-OpenApiContext -Service 'S' -BaseUri 'https://a' -Proxy 'http://proxy.local:8080/' -ProxyCredential $credential)
            $handler.UseProxy | Should -BeTrue
            $handler.Proxy.Address.AbsoluteUri | Should -Be 'http://proxy.local:8080/'
            $handler.Proxy.Credentials.UserName | Should -Be 'proxyuser'
            $handler.Dispose()
        }
    }

    It 'accepts any certificate with SkipCertificateCheck' {
        InModuleScope -ModuleName tcs.openapi {
            $handler = Build-OpenApiHttpClientHandler -Context (Build-OpenApiContext -Service 'S' -BaseUri 'https://a' -SkipCertificateCheck $true)
            $handler.ServerCertificateCustomValidationCallback | Should -Not -BeNullOrEmpty
            $handler.ServerCertificateCustomValidationCallback.Invoke($null, $null, $null, [System.Net.Security.SslPolicyErrors]::RemoteCertificateChainErrors) | Should -BeTrue
            $handler.Dispose()
        }
    }
}
