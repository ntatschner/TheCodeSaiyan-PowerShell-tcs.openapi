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

Describe 'ConvertTo-OpenApiUriEncoded' {
    It 'keeps unreserved characters and encodes the rest as UTF-8' {
        InModuleScope -ModuleName tcs.openapi {
            ConvertTo-OpenApiUriEncoded -Value 'aZ09-._~' | Should -BeExactly 'aZ09-._~'
            ConvertTo-OpenApiUriEncoded -Value ":/?#[]@!$&'()*+,;= %" | Should -BeExactly '%3A%2F%3F%23%5B%5D%40%21%24%26%27%28%29%2A%2B%2C%3B%3D%20%25'
            ConvertTo-OpenApiUriEncoded -Value ([string][char]0x20AC) | Should -BeExactly '%E2%82%AC'
            ConvertTo-OpenApiUriEncoded -Value ([char]::ConvertFromUtf32(0x1F600)) | Should -BeExactly '%F0%9F%98%80'
            ConvertTo-OpenApiUriEncoded -Value '' | Should -BeExactly ''
        }
    }

    It 'keeps reserved characters with -AllowReserved' {
        InModuleScope -ModuleName tcs.openapi {
            ConvertTo-OpenApiUriEncoded -Value "a/b?c=d&e" -AllowReserved | Should -BeExactly 'a/b?c=d&e'
            ConvertTo-OpenApiUriEncoded -Value 'a b' -AllowReserved | Should -BeExactly 'a%20b'
        }
    }
}
