BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/New-TestOpenApiModel.ps1')
}

Describe 'ConvertTo-OpenApiGenLiteral' {
    It 'wraps text in single quotes' {
        InModuleScope tcs.openapi { ConvertTo-OpenApiGenLiteral -Value 'abc' } | Should -Be "'abc'"
    }

    It 'doubles single quotes, including typographic ones' {
        $text = "it's " + [char]0x2019 + 'x'
        $literal = InModuleScope tcs.openapi -Parameters @{ Text = $text } { param($Text) ConvertTo-OpenApiGenLiteral -Value $Text }
        $literal | Should -Be ("'it''s " + [char]0x2019 + [char]0x2019 + "x'")
        (Invoke-Expression -Command $literal) | Should -Be $text
    }

    It 'keeps $ and backticks literal' {
        $literal = InModuleScope tcs.openapi { ConvertTo-OpenApiGenLiteral -Value '$env:PATH `n' }
        (Invoke-Expression -Command $literal) | Should -Be '$env:PATH `n'
    }

    It 'turns $null into an empty literal' {
        InModuleScope tcs.openapi { ConvertTo-OpenApiGenLiteral -Value $null } | Should -Be "''"
    }
}
