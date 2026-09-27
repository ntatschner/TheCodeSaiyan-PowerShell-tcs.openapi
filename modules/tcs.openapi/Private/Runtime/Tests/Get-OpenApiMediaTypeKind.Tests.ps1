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

Describe 'Get-OpenApiMediaTypeKind' {
    It 'classifies <ContentType> as <Kind>' -ForEach @(
        @{ ContentType = 'application/json'; Kind = 'Json' }
        @{ ContentType = 'application/json; charset=utf-8'; Kind = 'Json' }
        @{ ContentType = 'application/problem+json'; Kind = 'Json' }
        @{ ContentType = 'Application/Vnd.Api+JSON'; Kind = 'Json' }
        @{ ContentType = 'application/x-www-form-urlencoded'; Kind = 'Form' }
        @{ ContentType = 'multipart/form-data; boundary=x'; Kind = 'Multipart' }
        @{ ContentType = 'text/plain'; Kind = 'Text' }
        @{ ContentType = 'application/xml'; Kind = 'Text' }
        @{ ContentType = 'application/atom+xml'; Kind = 'Text' }
        @{ ContentType = 'application/octet-stream'; Kind = 'Binary' }
        @{ ContentType = 'image/png'; Kind = 'Binary' }
        @{ ContentType = ''; Kind = 'Binary' }
    ) {
        InModuleScope -ModuleName tcs.openapi -Parameters @{ ContentType = $ContentType; Kind = $Kind } {
            Get-OpenApiMediaTypeKind -ContentType $ContentType | Should -Be $Kind
        }
    }
}
