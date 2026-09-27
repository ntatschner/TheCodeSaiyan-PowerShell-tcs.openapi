BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/New-TestOpenApiModel.ps1')
}

Describe 'Get-OpenApiGenMediaKind' {
    It 'classifies <ContentType> as <Kind>' -TestCases @(
        @{ ContentType = 'application/json'; Kind = 'json' }
        @{ ContentType = 'application/json; charset=utf-8'; Kind = 'json' }
        @{ ContentType = 'application/problem+json'; Kind = 'json' }
        @{ ContentType = 'text/json'; Kind = 'json' }
        @{ ContentType = '*/*'; Kind = 'json' }
        @{ ContentType = 'application/x-www-form-urlencoded'; Kind = 'form' }
        @{ ContentType = 'multipart/form-data'; Kind = 'multipart' }
        @{ ContentType = 'text/plain'; Kind = 'text' }
        @{ ContentType = 'application/xml'; Kind = 'text' }
        @{ ContentType = 'application/atom+xml'; Kind = 'text' }
        @{ ContentType = 'application/octet-stream'; Kind = 'binary' }
        @{ ContentType = 'image/png'; Kind = 'binary' }
        @{ ContentType = 'application/pdf'; Kind = 'binary' }
    ) {
        param($ContentType, $Kind)
        InModuleScope tcs.openapi -Parameters @{ ContentType = $ContentType } { param($ContentType) Get-OpenApiGenMediaKind -ContentType $ContentType } | Should -Be $Kind
    }

    It 'treats a binary string schema as binary' {
        $schema = New-TestSchema -Type string -Format binary
        InModuleScope tcs.openapi -Parameters @{ Schema = $schema } { param($Schema) Get-OpenApiGenMediaKind -ContentType '*/*' -Schema $Schema } | Should -Be 'binary'
        InModuleScope tcs.openapi -Parameters @{ Schema = $schema } { param($Schema) Get-OpenApiGenMediaKind -ContentType 'multipart/form-data' -Schema $Schema } | Should -Be 'multipart'
    }
}
