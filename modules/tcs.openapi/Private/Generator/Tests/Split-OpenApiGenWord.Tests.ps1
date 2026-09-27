BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/New-TestOpenApiModel.ps1')
}

Describe 'Split-OpenApiGenWord' {
    It 'splits <Value>' -TestCases @(
        @{ Value = 'getPetById'; Expected = @('get', 'Pet', 'By', 'Id') }
        @{ Value = 'GetPetByID'; Expected = @('Get', 'Pet', 'By', 'ID') }
        @{ Value = 'list_all-pets'; Expected = @('list', 'all', 'pets') }
        @{ Value = 'XMLHttpRequest'; Expected = @('XML', 'Http', 'Request') }
        @{ Value = 'X-Request-Id'; Expected = @('X', 'Request', 'Id') }
        @{ Value = '$filter'; Expected = @('filter') }
        @{ Value = 'page[size]'; Expected = @('page', 'size') }
        @{ Value = 'v2Beta'; Expected = @('v2', 'Beta') }
        @{ Value = 'pets.find by tag'; Expected = @('pets', 'find', 'by', 'tag') }
    ) {
        param($Value, $Expected)
        $words = InModuleScope tcs.openapi -Parameters @{ Value = $Value } { param($Value) @(Split-OpenApiGenWord -Value $Value) }
        $words | Should -Be $Expected
    }

    It 'returns nothing for text without letters or digits' {
        InModuleScope tcs.openapi { @(Split-OpenApiGenWord -Value '$-_').Count } | Should -Be 0
        InModuleScope tcs.openapi { @(Split-OpenApiGenWord -Value '').Count } | Should -Be 0
    }
}
