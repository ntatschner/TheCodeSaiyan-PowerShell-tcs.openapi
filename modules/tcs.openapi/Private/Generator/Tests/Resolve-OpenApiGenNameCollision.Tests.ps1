BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/New-TestOpenApiModel.ps1')
}

Describe 'Resolve-OpenApiGenNameCollision' {
    BeforeAll {
        function New-Candidate {
            param([string]$OperationId, [string]$Method, [string]$Path, [string]$Verb, [string]$Noun)
            [pscustomobject]@{ OperationId = $OperationId; Method = $Method; Path = $Path; Verb = $Verb; Noun = $Noun; BaseNoun = $Noun; Name = "$Verb-$Noun"; Source = 'operationId'; IsList = $false; Findings = @() }
        }
        function Resolve-Test {
            param([object[]]$Candidate, [string[]]$Reserved = @())
            InModuleScope tcs.openapi -Parameters @{ Candidate = $Candidate; Reserved = $Reserved } {
                param($Candidate, $Reserved)
                Resolve-OpenApiGenNameCollision -Candidate $Candidate -Reserved $Reserved
            }
        }
    }

    It 'keeps unique names' {
        $result = Resolve-Test -Candidate @((New-Candidate 'a' 'GET' '/a' 'Get' 'A'), (New-Candidate 'b' 'GET' '/b' 'Get' 'B'))
        $result.Names.Name | Should -Be @('Get-A', 'Get-B')
        $result.Names.Renamed | Should -Be @($false, $false)
        $result.Findings.Count | Should -Be 0
    }

    It 'adds the distinguishing path parameter as By<Name>' {
        $result = Resolve-Test -Candidate @(
            (New-Candidate 'getOwner' 'GET' '/pets/{petId}/owner' 'Get' 'PetOwner'),
            (New-Candidate 'getOwnerByName' 'GET' '/pets/owner/{name}' 'Get' 'PetOwner')
        )
        $result.Names.Name | Should -Be @('Get-PetOwner', 'Get-PetOwnerByName')
        $result.Names[1].Renamed | Should -BeTrue
        $result.Findings.Count | Should -Be 1
        $result.Findings[0].Code | Should -Be 'OA040'
        $result.Findings[0].Severity | Should -Be 'Warning'
        $result.Findings[0].Operation | Should -Be 'getOwnerByName'
        $result.Findings[0].Message | Should -Match "Get-PetOwnerByName"
    }

    It 'adds a distinguishing literal segment, singularised' {
        $result = Resolve-Test -Candidate @(
            (New-Candidate 'a' 'GET' '/pets' 'Get' 'Pet'),
            (New-Candidate 'b' 'GET' '/archived/pets' 'Get' 'Pet')
        )
        $result.Names[1].Name | Should -Be 'Get-PetArchived'
    }

    It 'adds the method when the paths are the same' {
        $result = Resolve-Test -Candidate @(
            (New-Candidate 'a' 'POST' '/things' 'Set' 'Thing'),
            (New-Candidate 'b' 'PUT' '/things' 'Set' 'Thing')
        )
        $result.Names.Name | Should -Be @('Set-Thing', 'Set-ThingPut')
    }

    It 'falls back to a number, never a hash' {
        $result = Resolve-Test -Candidate @(
            (New-Candidate 'a' 'GET' '/things' 'Get' 'Thing'),
            (New-Candidate 'b' 'GET' '/things' 'Get' 'Thing'),
            (New-Candidate 'c' 'GET' '/things' 'Get' 'Thing')
        )
        $result.Names.Name | Should -Be @('Get-Thing', 'Get-ThingGet', 'Get-Thing2')
    }

    It 'never takes the base name of a later operation' {
        $result = Resolve-Test -Candidate @(
            (New-Candidate 'a' 'POST' '/things' 'Set' 'Thing'),
            (New-Candidate 'b' 'PUT' '/things' 'Set' 'Thing'),
            (New-Candidate 'c' 'GET' '/zzz' 'Set' 'ThingPut')
        )
        $result.Names.Name | Should -Be @('Set-Thing', 'Set-Thing2', 'Set-ThingPut')
    }

    It 'treats reserved names as taken, ignoring case' {
        $result = Resolve-Test -Candidate @((New-Candidate 'a' 'GET' '/context' 'Get' 'ShopContext')) -Reserved @('get-shopcontext')
        $result.Names[0].Name | Should -Be 'Get-ShopContextContext'
        $result.Findings[0].Message | Should -Match 'a command of the generated module'
    }

    It 'compares names without case' {
        $result = Resolve-Test -Candidate @((New-Candidate 'a' 'GET' '/a' 'Get' 'Pet'), (New-Candidate 'b' 'GET' '/a' 'Get' 'PET'))
        $result.Names[1].Renamed | Should -BeTrue
    }

    It 'is deterministic' {
        $candidates = @((New-Candidate 'a' 'GET' '/x/{id}' 'Get' 'X'), (New-Candidate 'b' 'GET' '/x/{name}' 'Get' 'X'))
        (Resolve-Test -Candidate $candidates).Names.Name | Should -Be (Resolve-Test -Candidate $candidates).Names.Name
        (Resolve-Test -Candidate $candidates).Names[1].Name | Should -Be 'Get-XByName'
    }
}
