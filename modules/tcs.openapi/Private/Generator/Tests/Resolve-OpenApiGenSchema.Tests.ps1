BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/New-TestOpenApiModel.ps1')
}

Describe 'Resolve-OpenApiGenSchema' {
    BeforeAll {
        $address = New-TestSchema -Type object -RefName 'Address' -Properties ([ordered]@{ city = New-TestSchema -Type string })
        $schemas = [ordered]@{ Address = $address }
    }

    It 'returns the named schema for a stub' {
        $stub = New-TestSchema -RefName 'Address'
        $resolved = InModuleScope tcs.openapi -Parameters @{ Stub = $stub; Schemas = $schemas } { param($Stub, $Schemas) Resolve-OpenApiGenSchema -Schema $Stub -Schemas $Schemas }
        [object]::ReferenceEquals($resolved, $address) | Should -BeTrue
    }

    It 'returns a schema that has properties or composition as it is' {
        $full = New-TestSchema -Type object -RefName 'Address' -Properties ([ordered]@{ zip = New-TestSchema -Type string })
        $composed = New-TestSchema -RefName 'Address' -OneOf @((New-TestSchema -Type string))
        foreach ($schema in @($full, $composed)) {
            $resolved = InModuleScope tcs.openapi -Parameters @{ Schema = $schema; Schemas = $schemas } { param($Schema, $Schemas) Resolve-OpenApiGenSchema -Schema $Schema -Schemas $Schemas }
            [object]::ReferenceEquals($resolved, $schema) | Should -BeTrue
        }
    }

    It 'returns the stub when the name is unknown or there is no schema map' {
        $stub = New-TestSchema -RefName 'Unknown'
        [object]::ReferenceEquals((InModuleScope tcs.openapi -Parameters @{ Stub = $stub; Schemas = $schemas } { param($Stub, $Schemas) Resolve-OpenApiGenSchema -Schema $Stub -Schemas $Schemas }), $stub) | Should -BeTrue
        [object]::ReferenceEquals((InModuleScope tcs.openapi -Parameters @{ Stub = $stub } { param($Stub) Resolve-OpenApiGenSchema -Schema $Stub -Schemas $null }), $stub) | Should -BeTrue
    }

    It 'reads a PSCustomObject schema map' {
        $stub = New-TestSchema -RefName 'Address'
        $map = [pscustomobject]@{ Address = $address }
        [object]::ReferenceEquals((InModuleScope tcs.openapi -Parameters @{ Stub = $stub; Schemas = $map } { param($Stub, $Schemas) Resolve-OpenApiGenSchema -Schema $Stub -Schemas $Schemas }), $address) | Should -BeTrue
    }
}
