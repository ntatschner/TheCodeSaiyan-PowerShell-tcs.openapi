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

Describe 'ConvertFrom-OpenApiHttpHeader' {
    It 'merges response and content headers case-insensitively' {
        InModuleScope -ModuleName tcs.openapi {
            $message = New-Object System.Net.Http.HttpResponseMessage -ArgumentList ([System.Net.HttpStatusCode]::OK)
            $message.Headers.Add('X-One', 'a')
            $message.Headers.Add('X-Many', 'b')
            $message.Headers.Add('X-Many', 'c')
            $message.Content = New-Object System.Net.Http.StringContent -ArgumentList 'x'
            $headers = ConvertFrom-OpenApiHttpHeader -Response $message
            $headers['x-one'] | Should -Be 'a'
            $headers['X-Many'] | Should -Be @('b', 'c')
            $headers['Content-Type'] | Should -Match '^text/plain'
            $message.Dispose()
        }
    }
}
