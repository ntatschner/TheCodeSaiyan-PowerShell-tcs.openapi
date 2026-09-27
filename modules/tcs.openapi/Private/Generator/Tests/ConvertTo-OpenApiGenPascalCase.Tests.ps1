BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/New-TestOpenApiModel.ps1')
}

Describe 'ConvertTo-OpenApiGenPascalCase' {
    It 'converts <Value> to <Expected>' -TestCases @(
        @{ Value = 'X-Request-Id'; Expected = 'XRequestId' }
        @{ Value = 'user_id'; Expected = 'UserId' }
        @{ Value = 'petID'; Expected = 'PetId' }
        @{ Value = '$filter'; Expected = 'Filter' }
        @{ Value = 'page[size]'; Expected = 'PageSize' }
        @{ Value = 'api-version'; Expected = 'ApiVersion' }
    ) {
        param($Value, $Expected)
        InModuleScope tcs.openapi -Parameters @{ Value = $Value } { param($Value) ConvertTo-OpenApiGenPascalCase -Value $Value } | Should -BeExactly $Expected
    }

    It 'removes accents and keeps only A-Z, a-z and 0-9' {
        $value = [string][char]0xC4 + 'rger_st' + [char]0xE9
        InModuleScope tcs.openapi -Parameters @{ Value = $value } { param($Value) ConvertTo-OpenApiGenPascalCase -Value $Value } | Should -BeExactly 'ArgerSte'
    }

    It 'joins a word list and skips empty words' {
        InModuleScope tcs.openapi { ConvertTo-OpenApiGenPascalCase -Word @('by', '', 'NAME') } | Should -BeExactly 'ByName'
    }
}
