BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/New-TestOpenApiModel.ps1')

    function Get-TreeContent {
        param([string]$Path)
        $root = (Resolve-Path -LiteralPath $Path).ProviderPath
        $result = @{}
        foreach ($file in Get-ChildItem -LiteralPath $root -Recurse -File) {
            $result[$file.FullName.Substring($root.Length).Replace('\', '/')] = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($file.FullName))
        }
        $result
    }
}

Describe 'New-OpenApiModule' {
    BeforeEach {
        $out = Join-Path -Path $TestDrive -ChildPath ([guid]::NewGuid().ToString('n'))
    }

    It 'writes the module and returns the result object' {
        $result = New-OpenApiModule -Document (New-TestOpenApiModel -Name petstore) -ModuleName 'PetStore' -OutputPath $out -NounPrefix 'PetStore'
        $result.PSObject.TypeNames | Should -Contain 'Tcs.OpenApi.GenerationResult'
        $result.ModuleName | Should -Be 'PetStore'
        $result.Path | Should -Be (Join-Path -Path $out -ChildPath 'PetStore')
        $result.ManifestPath | Should -Be (Join-Path -Path $result.Path -ChildPath 'PetStore.psd1')
        Test-Path -LiteralPath $result.ManifestPath | Should -BeTrue
        $pet = $result.Functions | Where-Object -FilterScript { $_.OperationId -eq 'showPetById' }
        $pet.Name | Should -Be 'Get-PetStorePetById'
        $pet.File | Should -Be 'Public/Pets/Get-PetStorePetById.ps1'
        $pet.Action | Should -Be 'Created'
        @($result.Skipped).Count | Should -Be 0
        @($result.Files).Count | Should -Be 18
        Test-ModuleManifest -Path $result.ManifestPath -ErrorAction SilentlyContinue | Out-Null
        (Import-PowerShellDataFile -Path $result.ManifestPath).FunctionsToExport.Count | Should -Be 12
    }

    It 'requires tcs.openapi at the version of the generator' {
        $result = New-OpenApiModule -Document (New-TestOpenApiModel -Name petstore) -ModuleName 'PetStore' -OutputPath $out
        $version = (Import-PowerShellDataFile -Path (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1')).ModuleVersion
        (Import-PowerShellDataFile -Path $result.ManifestPath).RequiredModules[0].ModuleVersion | Should -Be $version
    }

    It 'merges the document findings with the generator findings' {
        $result = New-OpenApiModule -Document (New-TestOpenApiModel -Name reserved) -ModuleName 'Reserved' -OutputPath $out
        $codes = @($result.Findings.Code)
        $codes | Should -Contain 'OA020'
        $codes | Should -Contain 'OA040'
        $codes | Should -Contain 'OA041'
        $codes | Should -Contain 'OA070'
        $codes[0] | Should -Be 'OA020' -Because 'the document findings come first'
        $result.Skipped.OperationId | Should -Be @('getRemote')
    }

    It 'accepts the document from the pipeline' {
        $result = New-TestOpenApiModel -Name bodies | New-OpenApiModule -ModuleName 'Shop' -OutputPath $out -NounPrefix 'Shop'
        $result.Functions.Name | Should -Contain 'New-ShopOrder'
    }

    It 'writes nothing with -WhatIf' {
        $result = New-OpenApiModule -Document (New-TestOpenApiModel -Name petstore) -ModuleName 'PetStore' -OutputPath $out -WhatIf
        Test-Path -LiteralPath $out | Should -BeFalse
        @($result.Files.Action | Select-Object -Unique) | Should -Be @('Skipped')
        @($result.Functions.Action | Select-Object -Unique) | Should -Be @('Skipped')
    }

    It 'produces byte-identical output for the same input' {
        $first = Join-Path -Path $out -ChildPath 'one'
        $second = Join-Path -Path $out -ChildPath 'two'
        New-OpenApiModule -Document (New-TestOpenApiModel -Name bodies) -ModuleName 'Shop' -OutputPath $first -NounPrefix 'Shop' | Out-Null
        New-OpenApiModule -Document (New-TestOpenApiModel -Name bodies) -ModuleName 'Shop' -OutputPath $second -NounPrefix 'Shop' | Out-Null
        $a = Get-TreeContent -Path $first
        $b = Get-TreeContent -Path $second
        @($a.Keys | Sort-Object) | Should -Be @($b.Keys | Sort-Object)
        foreach ($key in $a.Keys) {
            $b[$key] | Should -BeExactly $a[$key] -Because $key
        }
    }

    Context 'regenerating' {
        BeforeEach {
            $result = New-OpenApiModule -Document (New-TestOpenApiModel -Name petstore) -ModuleName 'PetStore' -OutputPath $out -NounPrefix 'PetStore'
            $overrides = Join-Path -Path $result.Path -ChildPath 'Overrides.ps1'
            $generated = Join-Path -Path $result.Path -ChildPath 'README.md'
        }

        It 'reports unchanged files when nothing changed' {
            $again = New-OpenApiModule -Document (New-TestOpenApiModel -Name petstore) -ModuleName 'PetStore' -OutputPath $out -NounPrefix 'PetStore'
            @($again.Files | Where-Object -FilterScript { $_.RelativePath -ne 'Overrides.ps1' } | ForEach-Object -Process { $_.Action } | Select-Object -Unique) | Should -Be @('Unchanged')
            ($again.Files | Where-Object -FilterScript { $_.RelativePath -eq 'Overrides.ps1' }).Action | Should -Be 'Preserved'
        }

        It 'refuses to replace changed generated files without -Force' {
            Add-Content -LiteralPath $generated -Value 'edited'
            { New-OpenApiModule -Document (New-TestOpenApiModel -Name petstore) -ModuleName 'PetStore' -OutputPath $out -NounPrefix 'PetStore' -ErrorAction Stop } | Should -Throw '*-Force*'
            Get-Content -LiteralPath $generated -Raw | Should -Match 'edited'
        }

        It 'replaces changed generated files with -Force and keeps Overrides.ps1' {
            Add-Content -LiteralPath $generated -Value 'edited'
            Set-Content -LiteralPath $overrides -Value 'function Get-PetStoreHealth { ''mine'' }'
            $again = New-OpenApiModule -Document (New-TestOpenApiModel -Name petstore) -ModuleName 'PetStore' -OutputPath $out -NounPrefix 'PetStore' -Force
            ($again.Files | Where-Object -FilterScript { $_.RelativePath -eq 'README.md' }).Action | Should -Be 'Replaced'
            ($again.Files | Where-Object -FilterScript { $_.RelativePath -eq 'Overrides.ps1' }).Action | Should -Be 'Preserved'
            Get-Content -LiteralPath $generated -Raw | Should -Not -Match 'edited'
            Get-Content -LiteralPath $overrides -Raw | Should -Match 'mine'
        }

        It 'removes the command of an operation that was removed from the document, with -Force' {
            $document = New-TestOpenApiModel -Name petstore
            $document.Operations = @($document.Operations | Where-Object -FilterScript { $_.OperationId -ne 'getPetPhoto' })
            $again = New-OpenApiModule -Document $document -ModuleName 'PetStore' -OutputPath $out -NounPrefix 'PetStore' -Force
            ($again.Files | Where-Object -FilterScript { $_.RelativePath -eq 'Public/Pets/Get-PetStorePetPhoto.ps1' }).Action | Should -Be 'Removed'
            Test-Path -LiteralPath (Join-Path -Path $result.Path -ChildPath 'Public/Pets/Get-PetStorePetPhoto.ps1') | Should -BeFalse
        }
    }

    It 'fails clearly for -Path when Import-OpenApiDocument is not available' {
        Mock -ModuleName tcs.openapi Get-Command { $null } -ParameterFilter { $Name -eq 'Import-OpenApiDocument' }
        { New-OpenApiModule -Path (Join-Path -Path $TestDrive -ChildPath 'x.json') -ModuleName 'X' -OutputPath $out -ErrorAction Stop } | Should -Throw '*Import-OpenApiDocument*-Document*'
    }

    It 'reads -Path and -Uri with Import-OpenApiDocument when it is available' {
        function global:Import-TestDocumentStub {
            param([string]$Path, [uri]$Uri)
            $global:TestImportArguments = @($Path, $Uri)
            New-TestOpenApiModel -Name petstore
        }
        try {
            Mock -ModuleName tcs.openapi Get-Command { Microsoft.PowerShell.Core\Get-Command -Name 'Import-TestDocumentStub' } -ParameterFilter { $Name -eq 'Import-OpenApiDocument' }
            $result = New-OpenApiModule -Path './petstore.json' -ModuleName 'PetStore' -OutputPath $out
            $global:TestImportArguments[0] | Should -Be './petstore.json'
            $result.Functions.Count | Should -Be 12
            New-OpenApiModule -Uri 'https://example.com/openapi.json' -ModuleName 'PetStore2' -OutputPath $out | Out-Null
            [string]$global:TestImportArguments[1] | Should -Be 'https://example.com/openapi.json'
        }
        finally {
            Remove-Item -Path 'function:global:Import-TestDocumentStub' -ErrorAction SilentlyContinue
            Remove-Variable -Name TestImportArguments -Scope Global -ErrorAction SilentlyContinue
        }
    }

    It 'rejects an object that is not a document model' {
        { New-OpenApiModule -Document ([pscustomobject]@{ Title = 'x' }) -ModuleName 'X' -OutputPath $out -ErrorAction Stop } | Should -Throw '*no Operations*'
    }

    It 'stores -UnwrapProperty in the metadata of the operations whose response has that property' {
        $wrapped = New-TestSchema -Type object -Properties ([ordered]@{ data = New-TestSchema -Type object -RefName 'Host'; traceId = New-TestSchema -Type string })
        $plain = New-TestSchema -Type object -Properties ([ordered]@{ success = New-TestSchema -Type boolean })
        $document = New-TestDocument -Operations @(
            (New-TestOperation -OperationId 'getHost' -Method GET -Path '/hosts/{id}' -Parameters @((New-TestParameter -Name 'id' -In path)) -Responses @((New-TestResponse -Content @((New-TestMediaType -ContentType 'application/json' -Schema $wrapped)))))
            (New-TestOperation -OperationId 'ping' -Method POST -Path '/ping' -Responses @((New-TestResponse -Content @((New-TestMediaType -ContentType 'application/json' -Schema $plain)))))
        )
        $result = New-OpenApiModule -Document $document -ModuleName 'Wrap' -OutputPath $out -NounPrefix 'W' -UnwrapProperty 'data'
        $metadata = Get-Content -LiteralPath (Join-Path -Path $result.Path -ChildPath 'OpenApi/operations.json') -Raw | ConvertFrom-Json
        $metadata[0].OperationId | Should -Be 'getHost'
        $metadata[0].UnwrapProperty | Should -Be 'data'
        $metadata[0].ResponseTypeName | Should -Be 'Wrap.Host'
        $metadata[1].PSObject.Properties.Name | Should -Not -Contain 'UnwrapProperty'
        Get-Content -LiteralPath (Join-Path -Path $result.Path -ChildPath 'Public/Default/Get-WHost.ps1') -Raw | Should -Match "OutputType\('Wrap.Host'\)"
    }

    It 'rejects an invalid module name or noun prefix' {
        { New-OpenApiModule -Document (New-TestDocument) -ModuleName '1x' -OutputPath $out } | Should -Throw
        { New-OpenApiModule -Document (New-TestDocument) -ModuleName 'X' -NounPrefix 'a-b' -OutputPath $out } | Should -Throw
    }

    It 'has help with a synopsis, a description, every parameter and examples' {
        $help = Get-Help -Name New-OpenApiModule -Full
        $help.Synopsis | Should -Not -BeNullOrEmpty
        $help.Description | Should -Not -BeNullOrEmpty
        @($help.Examples.Example).Count | Should -BeGreaterThan 0
        foreach ($name in @('Path', 'Uri', 'Document', 'ModuleName', 'OutputPath', 'NounPrefix', 'UnwrapProperty', 'ModuleVersion', 'Author', 'Force')) {
            ($help.Parameters.Parameter | Where-Object -FilterScript { $_.Name -eq $name }).Description | Should -Not -BeNullOrEmpty -Because $name
        }
    }
}
