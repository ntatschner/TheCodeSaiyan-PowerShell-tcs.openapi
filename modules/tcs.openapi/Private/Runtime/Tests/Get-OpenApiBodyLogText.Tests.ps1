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

Describe 'Get-OpenApiBodyLogText' {
    It 'shows text bodies with secrets redacted' {
        InModuleScope -ModuleName tcs.openapi {
            $content = Build-OpenApiHttpContent -Body ([ordered]@{ user = 'u'; password = 'p' }) -ContentType 'application/json'
            Get-OpenApiBodyLogText -Content $content | Should -BeExactly '{"user":"u","password":"********"}'
        }
    }

    It 'summarises binary and multipart bodies' {
        InModuleScope -ModuleName tcs.openapi {
            $binary = Build-OpenApiHttpContent -Body ([byte[]](1, 2, 3)) -ContentType 'application/octet-stream'
            Get-OpenApiBodyLogText -Content $binary | Should -Be '[application/octet-stream content, 3 bytes]'
            $multipart = Build-OpenApiHttpContent -Body @{ password = 'p' } -ContentType 'multipart/form-data'
            Get-OpenApiBodyLogText -Content $multipart | Should -Match '^\[multipart/form-data content'
        }
    }
}
