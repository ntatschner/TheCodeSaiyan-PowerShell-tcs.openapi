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

Describe 'Format-OpenApiHeaderLog' {
    It 'writes one line per header and masks secret values' {
        InModuleScope -ModuleName tcs.openapi {
            $headers = [ordered]@{ Accept = 'application/json'; Authorization = 'Bearer abc'; 'X-Custom-Key' = 'k1'; 'X-Plain' = @('a', 'b') }
            $text = Format-OpenApiHeaderLog -Header $headers -SensitiveName 'X-Custom-Key'
            $lines = $text -split [Environment]::NewLine
            $lines | Should -Be @('  Accept: application/json', '  Authorization: ********', '  X-Custom-Key: ********', '  X-Plain: a, b')
            Format-OpenApiHeaderLog -Header $null | Should -BeExactly ''
        }
    }
}
