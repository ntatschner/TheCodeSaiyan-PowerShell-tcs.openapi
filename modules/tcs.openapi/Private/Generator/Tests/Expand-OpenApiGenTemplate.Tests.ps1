BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/New-TestOpenApiModel.ps1')
}

Describe 'Expand-OpenApiGenTemplate' {
    It 'replaces placeholders' {
        InModuleScope tcs.openapi { Expand-OpenApiGenTemplate -Template 'a {{X}} b {{Y}} {{X}}' -Value @{ X = '1'; Y = '2' } } | Should -BeExactly 'a 1 b 2 1'
    }

    It 'removes a line that holds only an empty placeholder' {
        InModuleScope tcs.openapi { Expand-OpenApiGenTemplate -Template "a`n    {{X}}`nb`n" -Value @{ X = '' } } | Should -BeExactly "a`nb`n"
    }

    It 'keeps a placeholder line with a multi-line value' {
        InModuleScope tcs.openapi { Expand-OpenApiGenTemplate -Template "a`n{{X}}`nb" -Value @{ X = "1`n2" } } | Should -BeExactly "a`n1`n2`nb"
    }

    It 'fails for a placeholder without a value' {
        { InModuleScope tcs.openapi { Expand-OpenApiGenTemplate -Template '{{Missing}}' -Value @{} } } | Should -Throw '*Missing*'
    }

    It 'inserts values literally, including $ and braces' {
        InModuleScope tcs.openapi { Expand-OpenApiGenTemplate -Template 'x={{X}}' -Value @{ X = '$1 {{Y}}' } } | Should -BeExactly 'x=$1 {{Y}}'
    }

    It 'converts CRLF to LF' {
        InModuleScope tcs.openapi { Expand-OpenApiGenTemplate -Template "a`r`nb" -Value @{} } | Should -BeExactly "a`nb"
    }
}
