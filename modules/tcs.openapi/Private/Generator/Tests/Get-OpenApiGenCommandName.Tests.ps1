BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/New-TestOpenApiModel.ps1')
}

Describe 'Get-OpenApiGenCommandName' {
    BeforeAll {
        function Get-TestName {
            param($Operation, [string]$Prefix = '', [switch]$Generated)
            InModuleScope tcs.openapi -Parameters @{ Operation = $Operation; Prefix = $Prefix; Generated = [bool]$Generated } {
                param($Operation, $Prefix, $Generated)
                Get-OpenApiGenCommandName -Operation $Operation -NounPrefix $Prefix -OperationIdGenerated:$Generated
            }
        }
    }

    It 'derives <Expected> from operationId <OperationId> (<Method>)' -TestCases @(
        @{ OperationId = 'listPets'; Method = 'GET'; Path = '/pets'; Expected = 'Get-Pet' }
        @{ OperationId = 'getPetById'; Method = 'GET'; Path = '/pets/{id}'; Expected = 'Get-PetById' }
        @{ OperationId = 'createPets'; Method = 'POST'; Path = '/pets'; Expected = 'New-Pet' }
        @{ OperationId = 'updatePet'; Method = 'PUT'; Path = '/pets/{id}'; Expected = 'Set-Pet' }
        @{ OperationId = 'updatePet'; Method = 'PATCH'; Path = '/pets/{id}'; Expected = 'Update-Pet' }
        @{ OperationId = 'delete_pet'; Method = 'DELETE'; Path = '/pets/{id}'; Expected = 'Remove-Pet' }
        @{ OperationId = 'start-vm-instances'; Method = 'POST'; Path = '/vms/{id}/start'; Expected = 'Start-VmInstance' }
        @{ OperationId = 'uploadFile'; Method = 'POST'; Path = '/files'; Expected = 'New-UploadFile' }
        @{ OperationId = 'PetsFindByStatus'; Method = 'GET'; Path = '/pets'; Expected = 'Get-PetsFindByStatus' }
        @{ OperationId = 'list'; Method = 'GET'; Path = '/users/{id}/policies'; Expected = 'Get-Policy' }
        @{ OperationId = 'listOrders_2'; Method = 'GET'; Path = '/orders'; Expected = 'Get-Order2' }
    ) {
        param($OperationId, $Method, $Path, $Expected)
        $name = Get-TestName -Operation (New-TestOperation -OperationId $OperationId -Method $Method -Path $Path)
        $name.Name | Should -BeExactly $Expected
        $name.Source | Should -Be 'operationId'
    }

    It 'marks list/search/find operations as lists' {
        (Get-TestName -Operation (New-TestOperation -OperationId 'searchOrders' -Method GET -Path '/orders')).IsList | Should -BeTrue
        (Get-TestName -Operation (New-TestOperation -OperationId 'getOrder' -Method GET -Path '/orders/{id}')).IsList | Should -BeFalse
    }

    It 'uses the method and the last non-parameter path segment without an operationId' {
        $name = Get-TestName -Operation (New-TestOperation -OperationId '' -Method GET -Path '/users/{userId}/pet-owners/{id}')
        $name.Name | Should -BeExactly 'Get-PetOwner'
        $name.Source | Should -Be 'path'
    }

    It 'uses the path rule when the document model generated the operationId' {
        $name = Get-TestName -Operation (New-TestOperation -OperationId 'headStoreItems' -Method HEAD -Path '/store/items') -Generated
        $name.Name | Should -BeExactly 'Test-Item'
    }

    It 'uses Root for the root path' {
        (Get-TestName -Operation (New-TestOperation -Method OPTIONS -Path '/')).Name | Should -BeExactly 'Get-Root'
    }

    It 'adds the noun prefix' {
        $name = Get-TestName -Operation (New-TestOperation -OperationId 'listPets' -Method GET -Path '/pets') -Prefix 'PetStore'
        $name.Name | Should -BeExactly 'Get-PetStorePet'
        $name.BaseNoun | Should -BeExactly 'Pet'
    }

    It 'lets x-ps-name win' {
        $operation = New-TestOperation -OperationId 'listPets' -Method GET -Path '/pets' -Extensions ([ordered]@{ 'x-ps-name' = 'measure-PetStatistic'; 'x-ps-verb' = 'Find' })
        $name = Get-TestName -Operation $operation -Prefix 'Store'
        $name.Name | Should -BeExactly 'Measure-PetStatistic'
        $name.Source | Should -Be 'x-ps-name'
        $name.Findings.Count | Should -Be 0
    }

    It 'uses x-ps-verb and x-ps-noun' {
        $operation = New-TestOperation -OperationId 'listPets' -Method GET -Path '/pets' -Extensions ([ordered]@{ 'x-ps-verb' = 'find'; 'x-ps-noun' = 'animal' })
        (Get-TestName -Operation $operation -Prefix 'Zoo').Name | Should -BeExactly 'Find-ZooAnimal'
    }

    It 'reads extensions from a PSCustomObject too' {
        $operation = New-TestOperation -OperationId 'listPets' -Method GET -Path '/pets'
        $operation.Extensions = [pscustomobject]@{ 'x-ps-noun' = 'Critter' }
        (Get-TestName -Operation $operation).Name | Should -BeExactly 'Get-Critter'
    }

    It 'ignores an unapproved x-ps-verb or an invalid x-ps-name with an OA040 warning' {
        $operation = New-TestOperation -OperationId 'listPets' -Method GET -Path '/pets' -Extensions ([ordered]@{ 'x-ps-verb' = 'Fetch'; 'x-ps-name' = 'Grab-Pet' })
        $name = Get-TestName -Operation $operation
        $name.Name | Should -BeExactly 'Get-Pet'
        $name.Findings.Count | Should -Be 2
        $name.Findings.Code | Should -Be @('OA040', 'OA040')
        $name.Findings[0].Severity | Should -Be 'Warning'
    }

    It 'always returns an approved verb' {
        $approved = @(Get-Verb | ForEach-Object -Process { $_.Verb })
        foreach ($method in @('GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS', 'TRACE')) {
            $approved | Should -Contain (Get-TestName -Operation (New-TestOperation -OperationId 'doSomething' -Method $method -Path '/x')).Verb
        }
    }

    It 'keeps only A-Z, a-z and 0-9 in the noun' {
        (Get-TestName -Operation (New-TestOperation -OperationId 'get_$weird.name[s]' -Method GET -Path '/x')).Name | Should -BeExactly 'Get-WeirdNameS'
    }
}
