BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/New-TestOpenApiModel.ps1')
}

Describe 'ConvertTo-OpenApiGenJson' {
    It 'writes scalars' {
        InModuleScope tcs.openapi {
            ConvertTo-OpenApiGenJson -InputObject $null | Should -Be 'null'
            ConvertTo-OpenApiGenJson -InputObject $true | Should -Be 'true'
            ConvertTo-OpenApiGenJson -InputObject 42 | Should -Be '42'
            ConvertTo-OpenApiGenJson -InputObject 1.5 | Should -Be '1.5'
            ConvertTo-OpenApiGenJson -InputObject ([long]9007199254740993) | Should -Be '9007199254740993'
        }
    }

    It 'escapes control characters, quotes and non-ASCII text' {
        $json = InModuleScope tcs.openapi { ConvertTo-OpenApiGenJson -InputObject ("a`"b\c`n" + [char]0xE9) }
        $json | Should -BeExactly '"a\"b\\c\n\u00e9"'
        ($json | ConvertFrom-Json) | Should -Be ("a`"b\c`n" + [char]0xE9)
    }

    It 'keeps ordered and object property order and sorts hashtables' {
        $json = InModuleScope tcs.openapi { ConvertTo-OpenApiGenJson -InputObject ([ordered]@{ z = @{ b = 1; a = 2 }; y = [pscustomobject]@{ d = 1; c = 2 } }) }
        $json | Should -BeExactly "{`n  `"z`": {`n    `"a`": 2,`n    `"b`": 1`n  },`n  `"y`": {`n    `"d`": 1,`n    `"c`": 2`n  }`n}"
    }

    It 'writes empty arrays and objects compactly' {
        InModuleScope tcs.openapi { ConvertTo-OpenApiGenJson -InputObject ([ordered]@{ a = @(); b = @{} }) } | Should -BeExactly "{`n  `"a`": [],`n  `"b`": {}`n}"
    }

    It 'writes a one-element array as an array' {
        InModuleScope tcs.openapi { ConvertTo-OpenApiGenJson -InputObject @('x') } | Should -BeExactly "[`n  `"x`"`n]"
    }

    It 'writes compressed JSON with -Compress' {
        InModuleScope tcs.openapi { ConvertTo-OpenApiGenJson -InputObject ([ordered]@{ a = @(1, 2); b = [ordered]@{ c = 'x' } }) -Compress } | Should -BeExactly '{"a":[1,2],"b":{"c":"x"}}'
    }

    It 'leaves out null and empty values with -SkipEmpty but keeps false and zero' {
        $value = [ordered]@{ a = $null; b = ''; c = @(); d = @{}; e = [pscustomobject]@{}; f = $false; g = 0; h = 'x' }
        InModuleScope tcs.openapi -Parameters @{ Value = $value } { param($Value) ConvertTo-OpenApiGenJson -InputObject $Value -Compress -SkipEmpty } | Should -BeExactly '{"f":false,"g":0,"h":"x"}'
    }

    It 'stops at reference cycles' {
        $json = InModuleScope tcs.openapi {
            $node = [pscustomobject]@{ RefName = 'Node'; Child = $null }
            $node.Child = $node
            ConvertTo-OpenApiGenJson -InputObject $node
        }
        $parsed = $json | ConvertFrom-Json
        $parsed.Child.RefName | Should -Be 'Node'
        $parsed.Child.Recursive | Should -BeTrue
    }

    It 'round-trips through ConvertFrom-Json' {
        $value = [ordered]@{ name = 'x'; list = @(1, 2); nested = [ordered]@{ ok = $false } }
        $json = InModuleScope tcs.openapi -Parameters @{ Value = $value } { param($Value) ConvertTo-OpenApiGenJson -InputObject $Value }
        $parsed = $json | ConvertFrom-Json
        $parsed.name | Should -Be 'x'
        $parsed.list | Should -Be @(1, 2)
        $parsed.nested.ok | Should -BeFalse
    }
}
