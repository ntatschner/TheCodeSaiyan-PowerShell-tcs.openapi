BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/New-TestOpenApiModel.ps1')
}

Describe 'Get-OpenApiGenParameterType' {
    BeforeAll {
        function Get-TestType {
            param($Schema, [string]$In = 'query', [switch]$Required, $Example)
            InModuleScope tcs.openapi -Parameters @{ Schema = $Schema; In = $In; Required = [bool]$Required; Example = $Example } {
                param($Schema, $In, $Required, $Example)
                Get-OpenApiGenParameterType -Schema $Schema -In $In -Required:$Required -Example $Example
            }
        }
    }

    It 'maps <Type>/<Format> to [<Expected>]' -TestCases @(
        @{ Type = 'string'; Format = ''; Expected = 'string' }
        @{ Type = 'string'; Format = 'date-time'; Expected = 'datetime' }
        @{ Type = 'string'; Format = 'binary'; Expected = 'object' }
        @{ Type = 'integer'; Format = 'int32'; Expected = 'int' }
        @{ Type = 'integer'; Format = 'int64'; Expected = 'long' }
        @{ Type = 'integer'; Format = ''; Expected = 'long' }
        @{ Type = 'number'; Format = 'float'; Expected = 'double' }
        @{ Type = 'object'; Format = ''; Expected = 'hashtable' }
        @{ Type = ''; Format = ''; Expected = 'object' }
    ) {
        param($Type, $Format, $Expected)
        (Get-TestType -Schema (New-TestSchema -Type $Type -Format $Format)).TypeName | Should -Be $Expected
    }

    It 'maps arrays to element arrays' {
        (Get-TestType -Schema (New-TestSchema -Type array -Items (New-TestSchema -Type integer -Format int32))).TypeName | Should -Be 'int[]'
        (Get-TestType -Schema (New-TestSchema -Type array -Items (New-TestSchema -Type object))).TypeName | Should -Be 'hashtable[]'
        (Get-TestType -Schema (New-TestSchema -Type array -Items (New-TestSchema -Type array))).TypeName | Should -Be 'object[]'
        (Get-TestType -Schema (New-TestSchema -Type array)).TypeName | Should -Be 'object[]'
    }

    It 'uses [switch] for optional booleans and [bool] for required and path booleans' {
        $boolean = New-TestSchema -Type boolean
        (Get-TestType -Schema $boolean -In query).TypeName | Should -Be 'switch'
        (Get-TestType -Schema $boolean -In header).IsSwitch | Should -BeTrue
        (Get-TestType -Schema $boolean -In query -Required).TypeName | Should -Be 'bool'
        (Get-TestType -Schema $boolean -In path -Required).TypeName | Should -Be 'bool'
    }

    It 'maps oneOf to [object]' {
        (Get-TestType -Schema (New-TestSchema -OneOf @((New-TestSchema -Type string), (New-TestSchema -Type integer)))).TypeName | Should -Be 'object'
    }

    It 'adds [AllowNull()] for nullable schemas' {
        (Get-TestType -Schema (New-TestSchema -Type string -Nullable)).Attributes | Should -Contain '[AllowNull()]'
    }

    It 'adds ValidateSet for enums, also for array items' {
        (Get-TestType -Schema (New-TestSchema -Type string -Enum @('a', "it's"))).Attributes | Should -Contain "[ValidateSet('a', 'it''s')]"
        (Get-TestType -Schema (New-TestSchema -Type array -Items (New-TestSchema -Type string -Enum @('x', 'y')))).Attributes | Should -Contain "[ValidateSet('x', 'y')]"
        (Get-TestType -Schema (New-TestSchema -Type integer -Format int32 -Enum @(1, 2))).Attributes | Should -Contain "[ValidateSet('1', '2')]"
    }

    It 'adds a case-sensitive ValidatePattern and skips an invalid pattern' {
        (Get-TestType -Schema (New-TestSchema -Type string -Pattern '^[a-z]+$')).Attributes | Should -Contain "[ValidatePattern('^[a-z]+$', Options = 'None')]"
        (Get-TestType -Schema (New-TestSchema -Type string -Pattern '([a-z')).Attributes.Count | Should -Be 0
    }

    It 'adds ValidateLength from minLength and maxLength' {
        (Get-TestType -Schema (New-TestSchema -Type string -MinLength 1 -MaxLength 5)).Attributes | Should -Contain '[ValidateLength(1, 5)]'
        (Get-TestType -Schema (New-TestSchema -Type string -MaxLength 5)).Attributes | Should -Contain '[ValidateLength(0, 5)]'
    }

    It 'adds ValidateRange with literals of one type' {
        (Get-TestType -Schema (New-TestSchema -Type integer -Format int32 -Minimum 1 -Maximum 100)).Attributes | Should -Contain '[ValidateRange(1, 100)]'
        (Get-TestType -Schema (New-TestSchema -Type integer -Format int32 -Minimum 1)).Attributes | Should -Contain '[ValidateRange(1, 2147483647)]'
        (Get-TestType -Schema (New-TestSchema -Type integer -Minimum 0)).Attributes | Should -Contain '[ValidateRange(0l, 9223372036854775807l)]'
        (Get-TestType -Schema (New-TestSchema -Type number -Minimum 0 -Maximum 1.5)).Attributes | Should -Contain '[ValidateRange(0.0, 1.5)]'
    }

    It 'reads exclusive bounds as a flag or as the bound' {
        $flag = New-TestSchema -Type integer -Format int32 -Minimum 1 -Maximum 10
        $flag | Add-Member -NotePropertyName ExclusiveMinimum -NotePropertyValue $true
        $flag | Add-Member -NotePropertyName ExclusiveMaximum -NotePropertyValue $false
        (Get-TestType -Schema $flag).Attributes | Should -Contain '[ValidateRange(2, 10)]'
        $bound = New-TestSchema -Type integer -Format int32
        $bound | Add-Member -NotePropertyName ExclusiveMinimum -NotePropertyValue 0
        $bound | Add-Member -NotePropertyName ExclusiveMaximum -NotePropertyValue 5
        (Get-TestType -Schema $bound).Attributes | Should -Contain '[ValidateRange(1, 4)]'
    }

    It 'uses the schema example when the parameter has none' {
        $schema = New-TestSchema -Type string
        $schema | Add-Member -NotePropertyName Example -NotePropertyValue 'from-schema'
        (Get-TestType -Schema $schema).ExampleText | Should -Be "'from-schema'"
    }

    It 'looks up a schema stub without a type in the schema map and keeps its nullable flag' {
        $stub = New-TestSchema -RefName 'Address' -Nullable
        $schemas = [ordered]@{ Address = (New-TestSchema -Type object -RefName 'Address' -Properties ([ordered]@{ city = New-TestSchema -Type string })) }
        $type = InModuleScope tcs.openapi -Parameters @{ Schema = $stub; Schemas = $schemas } {
            param($Schema, $Schemas)
            Get-OpenApiGenParameterType -Schema $Schema -In 'body' -Schemas $Schemas
        }
        $type.TypeName | Should -Be 'hashtable'
        $type.Attributes | Should -Contain '[AllowNull()]'
        $arrayType = InModuleScope tcs.openapi -Parameters @{ Schema = (New-TestSchema -Type array -Items (New-TestSchema -RefName 'Address')); Schemas = $schemas } {
            param($Schema, $Schemas)
            Get-OpenApiGenParameterType -Schema $Schema -In 'body' -Schemas $Schemas
        }
        $arrayType.TypeName | Should -Be 'hashtable[]'
    }

    It 'adds ValidateCount from minItems and maxItems' {
        (Get-TestType -Schema (New-TestSchema -Type array -Items (New-TestSchema -Type string) -MinItems 1 -MaxItems 3)).Attributes | Should -Contain '[ValidateCount(1, 3)]'
    }

    It 'produces validation attributes that bind' {
        $schemas = @(
            (New-TestSchema -Type integer -Format int32 -Minimum 1 -Maximum 100),
            (New-TestSchema -Type integer -Maximum 5),
            (New-TestSchema -Type number -Minimum -1.5),
            (New-TestSchema -Type string -Pattern '^a' -MinLength 1),
            (New-TestSchema -Type array -Items (New-TestSchema -Type string -Enum @('a')) -MaxItems 2)
        )
        foreach ($schema in $schemas) {
            $type = Get-TestType -Schema $schema
            $source = "function Test-Bind { param($($type.Attributes -join ' ') [$($type.TypeName)]`$Value) }"
            $block = [scriptblock]::Create($source)
            { . $block; (Get-Command -Name Test-Bind).Parameters.Count } | Should -Not -Throw
        }
    }

    It 'builds an example from Example, enum or type' {
        (Get-TestType -Schema (New-TestSchema -Type string) -Example 'abc').ExampleText | Should -Be "'abc'"
        (Get-TestType -Schema (New-TestSchema -Type string -Enum @('open'))).ExampleText | Should -Be "'open'"
        (Get-TestType -Schema (New-TestSchema -Type integer)).ExampleText | Should -Be '1'
        (Get-TestType -Schema (New-TestSchema -Type string -Format date-time)).ExampleText | Should -Be '(Get-Date)'
        (Get-TestType -Schema (New-TestSchema -Type array -Items (New-TestSchema -Type string))).ExampleText | Should -Be "@('example')"
        (Get-TestType -Schema (New-TestSchema -Type boolean) -Required).ExampleText | Should -Be '$true'
        (Get-TestType -Schema (New-TestSchema -Type boolean)).ExampleText | Should -BeNullOrEmpty
    }
}
