BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/New-TestOpenApiModel.ps1')
}

Describe 'ConvertTo-OpenApiGenSingular' {
    It 'singularises <Word> to <Expected>' -TestCases @(
        @{ Word = 'Pets'; Expected = 'Pet' }
        @{ Word = 'Policies'; Expected = 'Policy' }
        @{ Word = 'Boxes'; Expected = 'Box' }
        @{ Word = 'Matches'; Expected = 'Match' }
        @{ Word = 'Addresses'; Expected = 'Address' }
        @{ Word = 'People'; Expected = 'Person' }
        @{ Word = 'Children'; Expected = 'Child' }
        @{ Word = 'Statuses'; Expected = 'Status' }
        @{ Word = 'Indices'; Expected = 'Index' }
        @{ Word = 'Ids'; Expected = 'Id' }
        @{ Word = 'Responses'; Expected = 'Response' }
        @{ Word = 'Caches'; Expected = 'Cache' }
        @{ Word = 'pets'; Expected = 'pet' }
    ) {
        param($Word, $Expected)
        InModuleScope tcs.openapi -Parameters @{ Word = $Word } { param($Word) ConvertTo-OpenApiGenSingular -Word $Word } | Should -BeExactly $Expected
    }

    It 'leaves <Word> unchanged' -TestCases @(
        @{ Word = 'Status' }, @{ Word = 'Address' }, @{ Word = 'Analysis' }, @{ Word = 'Data' }, @{ Word = 'Metadata' },
        @{ Word = 'News' }, @{ Word = 'Series' }, @{ Word = 'Pet' }, @{ Word = 'Is' }, @{ Word = 'Alias' }
    ) {
        param($Word)
        InModuleScope tcs.openapi -Parameters @{ Word = $Word } { param($Word) ConvertTo-OpenApiGenSingular -Word $Word } | Should -BeExactly $Word
    }
}
