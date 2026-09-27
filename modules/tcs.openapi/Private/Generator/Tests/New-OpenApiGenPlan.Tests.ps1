BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/New-TestOpenApiModel.ps1')
}

Describe 'New-OpenApiGenPlan' {
    BeforeAll {
        function New-TestPlan {
            param($Document, [string]$ModuleName = 'PetStore', [string]$NounPrefix = 'PetStore')
            InModuleScope tcs.openapi -Parameters @{ Document = $Document; ModuleName = $ModuleName; NounPrefix = $NounPrefix } {
                param($Document, $ModuleName, $NounPrefix)
                $option = Resolve-OpenApiGenOption -ModuleName $ModuleName -OutputPath '/out' -NounPrefix $NounPrefix -GeneratorVersion '0.1.0'
                $templates = Get-OpenApiGenTemplate -Path (Join-Path -Path $script:TcsOpenApiModuleRoot -ChildPath 'Templates')
                New-OpenApiGenPlan -Document $Document -Option $option -Template $templates
            }
        }
        $petstore = New-TestOpenApiModel -Name petstore
        $plan = New-TestPlan -Document $petstore
    }

    It 'plans the module layout' {
        $paths = @($plan.Files.RelativePath)
        foreach ($expected in @('PetStore.psd1', 'PetStore.psm1', 'README.md', 'Overrides.ps1', 'OpenApi/operations.json', 'OpenApi/source.json',
                'Public/Pets/Get-PetStorePet.ps1', 'Public/Pets/New-PetStorePet.ps1', 'Public/Store/Get-PetStoreInventory.ps1', 'Public/Default/Get-PetStoreHealth.ps1',
                'Public/_Connection/Set-PetStoreContext.ps1', 'Public/_Connection/Get-PetStoreContext.ps1', 'Public/_Connection/Remove-PetStoreContext.ps1')) {
            $paths | Should -Contain $expected
        }
        $plan.ModulePath | Should -Be (Join-Path -Path '/out' -ChildPath 'PetStore')
        $plan.ManifestPath | Should -Be (Join-Path -Path (Join-Path -Path '/out' -ChildPath 'PetStore') -ChildPath 'PetStore.psd1')
    }

    It 'marks Overrides.ps1 as the file that is never overwritten' {
        ($plan.Files | Where-Object -FilterScript { $_.RelativePath -eq 'Overrides.ps1' }).Kind | Should -Be 'Overrides'
    }

    It 'sorts files and functions ordinally' {
        $paths = @($plan.Files.RelativePath)
        $sorted = [string[]]$paths.Clone()
        [System.Array]::Sort($sorted, [System.StringComparer]::Ordinal)
        $paths | Should -Be $sorted
        $names = @($plan.Functions.Name)
        $sortedNames = [string[]]$names.Clone()
        [System.Array]::Sort($sortedNames, [System.StringComparer]::Ordinal)
        $names | Should -Be $sortedNames
    }

    It 'lists every function with its operation and file' {
        $pet = $plan.Functions | Where-Object -FilterScript { $_.OperationId -eq 'showPetById' }
        $pet.Name | Should -Be 'Get-PetStorePetById'
        $pet.File | Should -Be 'Public/Pets/Get-PetStorePetById.ps1'
        ($plan.Functions | Where-Object -FilterScript { $_.OperationId -eq 'petStats' }).Name | Should -Be 'Measure-PetStatistic'
        ($plan.Functions | Where-Object -FilterScript { $_.OperationId -eq 'getHealth' }).Name | Should -Be 'Get-PetStoreHealth'
    }

    It 'exports every function in the manifest' {
        $manifest = ($plan.Files | Where-Object -FilterScript { $_.Kind -eq 'Manifest' }).Content
        foreach ($name in $plan.Functions.Name) {
            $manifest | Should -Match ([regex]::Escape("'$name'"))
        }
    }

    It 'writes operation metadata sorted by operationId' {
        $json = ($plan.Files | Where-Object -FilterScript { $_.RelativePath -eq 'OpenApi/operations.json' }).Content
        $operations = $json | ConvertFrom-Json
        @($operations.OperationId) | Should -Be @('createPets', 'deletePet', 'getHealth', 'getInventory', 'getPetPhoto', 'listPets', 'petStats', 'showPetById', 'updatePet')
    }

    It 'writes the normalised document to source.json' {
        $json = ($plan.Files | Where-Object -FilterScript { $_.RelativePath -eq 'OpenApi/source.json' }).Content
        ($json | ConvertFrom-Json).Title | Should -Be 'Swagger Petstore'
    }

    It 'is deterministic' {
        $again = New-TestPlan -Document (New-TestOpenApiModel -Name petstore)
        for ($i = 0; $i -lt $plan.Files.Count; $i++) {
            $again.Files[$i].RelativePath | Should -BeExactly $plan.Files[$i].RelativePath
            $again.Files[$i].Content | Should -BeExactly $plan.Files[$i].Content
        }
    }

    It 'uses LF line endings only' {
        foreach ($file in $plan.Files) {
            $file.Content | Should -Not -Match "`r"
        }
    }

    It 'skips unsupported operations with OA070' {
        $reservedPlan = New-TestPlan -Document (New-TestOpenApiModel -Name reserved) -ModuleName 'Reserved' -NounPrefix ''
        $reservedPlan.Skipped.OperationId | Should -Be @('getRemote')
        ($reservedPlan.Findings | Where-Object -FilterScript { $_.Code -eq 'OA070' }).Operation | Should -Be 'getRemote'
        $reservedPlan.Functions.OperationId | Should -Not -Contain 'getRemote'
    }

    It 'collects OA040 and OA041 findings' {
        $reservedPlan = New-TestPlan -Document (New-TestOpenApiModel -Name reserved) -ModuleName 'Reserved' -NounPrefix ''
        @($reservedPlan.Findings | Where-Object -FilterScript { $_.Code -eq 'OA040' }).Count | Should -Be 3
        @($reservedPlan.Findings | Where-Object -FilterScript { $_.Code -eq 'OA041' }).Count | Should -BeGreaterThan 3
    }

    It 'skips an operation whose function does not bind, with an OA070 error' {
        InModuleScope tcs.openapi {
            Mock Test-OpenApiGenFunction { [pscustomobject]@{ IsValid = $false; Errors = @('Bind check failed: broken'); ParameterNames = @(); ParameterSets = @(); Syntax = $null } } -ParameterFilter { $FunctionName -eq 'Get-PetStorePet' }
        }
        $broken = New-TestPlan -Document $petstore
        $broken.Skipped.OperationId | Should -Be @('listPets')
        $finding = $broken.Findings | Where-Object -FilterScript { $_.Code -eq 'OA070' }
        $finding.Severity | Should -Be 'Error'
        $finding.Message | Should -Match 'broken'
        $broken.Functions.Name | Should -Not -Contain 'Get-PetStorePet'
        ($broken.Files | Where-Object -FilterScript { $_.RelativePath -eq 'OpenApi/operations.json' }).Content | Should -Not -Match 'listPets'
    }

    It 'never gives a command the name of an engine command or a connection command' {
        $document = New-TestDocument -Operations @(
            (New-TestOperation -OperationId 'invokeOpenApiRequest' -Method POST -Path '/x'),
            (New-TestOperation -OperationId 'getShopContext' -Method GET -Path '/context')
        )
        $names = (New-TestPlan -Document $document -ModuleName 'Shop' -NounPrefix '').Functions.Name
        $names | Should -Contain 'Invoke-OpenApiRequestX'
        $names | Should -Contain 'Get-ShopContextContext'
    }

    It 'skips an operation without an operationId or with a duplicate one' {
        $document = New-TestDocument -Operations @(
            (New-TestOperation -OperationId 'getA' -Method GET -Path '/a'),
            (New-TestOperation -OperationId 'getA' -Method GET -Path '/b'),
            (New-TestOperation -OperationId '' -Method GET -Path '/c')
        )
        $result = New-TestPlan -Document $document -ModuleName 'Dup' -NounPrefix ''
        $result.Functions.OperationId | Should -Contain 'getA'
        @($result.Skipped.Path) | Should -Be @('/b', '/c')
        @($result.Findings | Where-Object -FilterScript { $_.Code -eq 'OA070' -and $_.Severity -eq 'Error' }).Count | Should -Be 2
    }

    It 'plans a module for a document without operations' {
        $empty = New-TestPlan -Document (New-TestDocument) -ModuleName 'Empty' -NounPrefix ''
        ($empty.Files | Where-Object -FilterScript { $_.RelativePath -eq 'OpenApi/operations.json' }).Content | Should -Be "[]`n"
        $empty.Functions.Count | Should -Be 3
    }
}
