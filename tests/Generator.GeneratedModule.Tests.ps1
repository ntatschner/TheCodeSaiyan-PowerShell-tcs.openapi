# Imports generated modules with a stub tcs.openapi (a fake module of the same name and version in
# TestDrive) and checks what every wrapper passes to Invoke-OpenApiRequest.

BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $RepoRoot = Split-Path -Path $PSScriptRoot -Parent
    $ManifestPath = Join-Path -Path $RepoRoot -ChildPath 'modules/tcs.openapi/tcs.openapi.psd1'
    Import-Module -Name $ManifestPath -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath 'Helpers/New-TestOpenApiModel.ps1')

    # Generate the three modules with the real generator
    $OutputRoot = Join-Path -Path $TestDrive -ChildPath 'generated'
    $Generated = @{}
    foreach ($case in Get-TestSnapshotCase) {
        $parameters = @{ Document = (New-TestOpenApiModel -Name $case.Name); ModuleName = $case.ModuleName; OutputPath = $OutputRoot }
        if ($case.NounPrefix) {
            $parameters['NounPrefix'] = $case.NounPrefix
        }
        $Generated[$case.Name] = New-OpenApiModule @parameters
    }

    # A stub tcs.openapi with the same version that records every call
    $version = (Import-PowerShellDataFile -Path $ManifestPath).ModuleVersion
    $StubRoot = Join-Path -Path $TestDrive -ChildPath 'stub'
    $stubFolder = Join-Path -Path $StubRoot -ChildPath 'tcs.openapi'
    New-Item -Path $stubFolder -ItemType Directory -Force | Out-Null
    Set-Content -LiteralPath (Join-Path -Path $stubFolder -ChildPath 'tcs.openapi.psd1') -Value @"
@{
    RootModule        = 'tcs.openapi.psm1'
    ModuleVersion     = '$version'
    GUID              = 'fea600e7-039d-4cf2-b288-bbf335757db6'
    FunctionsToExport = @('Invoke-OpenApiRequest', 'Set-OpenApiContext', 'Get-OpenApiContext', 'Remove-OpenApiContext', 'Get-StubCall', 'Clear-StubCall')
}
"@
    Set-Content -LiteralPath (Join-Path -Path $stubFolder -ChildPath 'tcs.openapi.psm1') -Value @'
$script:Calls = New-Object -TypeName System.Collections.ArrayList
function Add-StubCall {
    param([string]$Command, [hashtable]$Parameters)
    [void]$script:Calls.Add([pscustomobject]@{ Command = $Command; Parameters = $Parameters })
}
function Invoke-OpenApiRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Service,
        [Parameter(Mandatory)][object]$Operation,
        [hashtable]$PathParameters,
        [hashtable]$QueryParameters,
        [hashtable]$HeaderParameters,
        [hashtable]$CookieParameters,
        [AllowNull()][object]$Body,
        [string]$ContentType,
        [string]$OutFile,
        [switch]$All,
        [switch]$Raw,
        [System.Management.Automation.PSCmdlet]$Cmdlet
    )
    Add-StubCall -Command 'Invoke-OpenApiRequest' -Parameters (@{} + $PSBoundParameters)
    'response'
}
function Set-OpenApiContext {
    [CmdletBinding()]
    param([string]$Service, [string]$BaseUri, [securestring]$ApiKey, [pscredential]$Credential, [securestring]$BearerToken,
        [string]$ClientId, [securestring]$ClientSecret, [string]$TokenUri, [string[]]$Scope, [hashtable]$Header, [int]$TimeoutSec,
        [string]$Proxy, [pscredential]$ProxyCredential, [switch]$SkipCertificateCheck, [int]$MaxRetries, [switch]$Persist, [switch]$PassThru)
    Add-StubCall -Command 'Set-OpenApiContext' -Parameters (@{} + $PSBoundParameters)
}
function Get-OpenApiContext {
    [CmdletBinding()]
    param([string]$Service)
    Add-StubCall -Command 'Get-OpenApiContext' -Parameters (@{} + $PSBoundParameters)
}
function Remove-OpenApiContext {
    [CmdletBinding()]
    param([string]$Service, [switch]$Persisted)
    Add-StubCall -Command 'Remove-OpenApiContext' -Parameters (@{} + $PSBoundParameters)
}
function Get-StubCall { $script:Calls.ToArray() }
function Clear-StubCall { $script:Calls.Clear() }
'@

    # Swap the real module for the stub
    Remove-Module -Name tcs.openapi -Force
    $OriginalModulePath = $env:PSModulePath
    $env:PSModulePath = $StubRoot + [System.IO.Path]::PathSeparator + $env:PSModulePath
    foreach ($name in $Generated.Keys) {
        Import-Module -Name $Generated[$name].ManifestPath -Force
    }

    function Get-LastRequest {
        @(Get-StubCall | Where-Object -FilterScript { $_.Command -eq 'Invoke-OpenApiRequest' })[-1].Parameters
    }
}

AfterAll {
    foreach ($name in @('PetStore', 'Reserved.Names', 'Shop', 'tcs.openapi')) {
        Remove-Module -Name $name -Force -ErrorAction SilentlyContinue
    }
    $env:PSModulePath = $OriginalModulePath
}

Describe 'Generated modules with a stub request engine' {
    BeforeEach {
        Clear-StubCall
    }

    Context 'import' {
        It 'loads the stub tcs.openapi as the required module' {
            (Get-Module -Name tcs.openapi).ModuleBase | Should -BeLike "$StubRoot*"
        }

        It 'exports exactly the planned functions of <_>' -ForEach @('PetStore', 'Reserved.Names', 'Shop') {
            $module = Get-Module -Name $_
            $expected = @((Import-PowerShellDataFile -Path (Join-Path -Path $module.ModuleBase -ChildPath "$_.psd1")).FunctionsToExport)
            @($module.ExportedFunctions.Keys | Sort-Object) | Should -Be @($expected | Sort-Object)
        }

        It 'binds every generated function' {
            foreach ($moduleName in @('PetStore', 'Reserved.Names', 'Shop')) {
                foreach ($command in (Get-Module -Name $moduleName).ExportedFunctions.Values) {
                    { Get-Command -Name $command.Name -Syntax -ErrorAction Stop } | Should -Not -Throw -Because $command.Name
                    $command.Parameters.Count | Should -BeGreaterThan 0
                }
            }
        }

        It 'loads the operation metadata keyed by operationId' {
            Get-PetStorePetById -PetId 'p1' | Out-Null
            $operation = (Get-LastRequest).Operation
            $operation.OperationId | Should -BeExactly 'showPetById'
            $operation.Method | Should -Be 'GET'
            $operation.Path | Should -Be '/pets/{petId}'
            $operation.PSObject.TypeNames | Should -Contain 'Tcs.OpenApi.OperationMetadata'
            @($operation.Parameters)[0].Name | Should -Be 'petId'
        }
    }

    Context 'parameters' {
        It 'passes path parameters keyed by spec name, the service and the cmdlet' {
            Get-PetStorePetById -PetId 'p1' | Should -Be 'response'
            $request = Get-LastRequest
            $request.Service | Should -Be 'PetStore'
            $request.PathParameters | Should -BeOfType [hashtable]
            $request.PathParameters['petId'] | Should -Be 'p1'
            @($request.PathParameters.Keys) | Should -Be @('petId')
            $request.Cmdlet | Should -BeOfType [System.Management.Automation.PSCmdlet]
            $request.ContainsKey('QueryParameters') | Should -BeFalse
            $request.ContainsKey('Body') | Should -BeFalse
            $request.ContainsKey('Raw') | Should -BeFalse
        }

        It 'passes only bound query parameters, with arrays' {
            Get-PetStorePet -Tags 'a', 'b' | Out-Null
            $request = Get-LastRequest
            @($request.QueryParameters.Keys) | Should -Be @('tags')
            $request.QueryParameters['tags'] | Should -Be @('a', 'b')
            Get-PetStorePet | Out-Null
            (Get-LastRequest).QueryParameters.Count | Should -Be 0
        }

        It 'passes -All and -Raw when bound' {
            Get-PetStorePet -Limit 5 -All -Raw | Out-Null
            $request = Get-LastRequest
            $request.QueryParameters['limit'] | Should -Be 5
            $request.All | Should -BeTrue
            $request.Raw | Should -BeTrue
        }

        It 'passes -OutFile for binary responses' {
            Get-PetStorePetPhoto -PetId 'p1' -OutFile 'photo.png' | Out-Null
            (Get-LastRequest).OutFile | Should -Be 'photo.png'
            Get-ShopReport -ReportId 7 -OutFile 'r.pdf' | Out-Null
            (Get-LastRequest).PathParameters['reportId'] | Should -Be 7
        }

        It 'validates values before calling the engine' {
            { Get-PetStorePet -Limit 0 } | Should -Throw
            { New-PetStorePet -Name 'Rex' -Status 'bogus' -Confirm:$false } | Should -Throw
            @(Get-StubCall).Count | Should -Be 0
        }

        It 'passes header, cookie and renamed parameters under their spec names' {
            Get-StockItem -ItemId 'i1' -DebugQuery -RawQuery 'r' -UserId 'u1' -UserIdQuery 'u2' -Filter 'f' -PageSize 10 -XRequestId 'x' -HostHeader 'h' -XStrict $false -SessionId 's' -Raw | Out-Null
            $request = Get-LastRequest
            $request.PathParameters['itemId'] | Should -Be 'i1'
            $request.QueryParameters['debug'] | Should -BeExactly $true
            $request.QueryParameters['Raw'] | Should -Be 'r'
            $request.QueryParameters['user_id'] | Should -Be 'u1'
            $request.QueryParameters['userId'] | Should -Be 'u2'
            $request.QueryParameters['$filter'] | Should -Be 'f'
            $request.QueryParameters['page[size]'] | Should -Be 10
            $request.QueryParameters.Count | Should -Be 6
            $request.HeaderParameters['X-Request-Id'] | Should -Be 'x'
            $request.HeaderParameters['Host'] | Should -Be 'h'
            $request.HeaderParameters['X-Strict'] | Should -BeExactly $false
            $request.CookieParameters['session_id'] | Should -Be 's'
            $request.Raw | Should -BeTrue
        }

        It 'sends an optional boolean switch as true or false only when bound' {
            Get-StockItem -ItemId 'i1' -XRequestId 'x' -XStrict $true -DebugQuery:$false | Out-Null
            (Get-LastRequest).QueryParameters['debug'] | Should -BeExactly $false
            Get-StockItem -ItemId 'i1' -XRequestId 'x' -XStrict $true | Out-Null
            (Get-LastRequest).QueryParameters.ContainsKey('debug') | Should -BeFalse
        }

        It 'accepts spec names as aliases and pipeline input by property name' {
            Get-StockItem -Id 'i2' -XRequestId 'x' -XStrict $true -session_id 's2' | Out-Null
            (Get-LastRequest).PathParameters['itemId'] | Should -Be 'i2'
            (Get-LastRequest).CookieParameters['session_id'] | Should -Be 's2'
            [pscustomobject]@{ itemId = 'i3'; 'X-Request-Id' = 'x3'; 'X-Strict' = $true } | Get-StockItem | Out-Null
            $request = Get-LastRequest
            $request.PathParameters['itemId'] | Should -Be 'i3'
            $request.HeaderParameters['X-Request-Id'] | Should -Be 'x3'
        }

        It 'passes arrays and dates in the query' {
            $since = Get-Date -Year 2026 -Month 1 -Day 2
            Get-ShopOrder -Status 'open', 'closed' -IncludeDeleted -Since $since -MinTotal 1.5 -All | Out-Null
            $request = Get-LastRequest
            $request.QueryParameters['status'] | Should -Be @('open', 'closed')
            $request.QueryParameters['include_deleted'] | Should -BeExactly $true
            $request.QueryParameters['since'] | Should -Be $since
            $request.QueryParameters['since'] | Should -BeOfType [datetime]
            $request.QueryParameters['min_total'] | Should -Be 1.5
            $request.All | Should -BeTrue
        }
    }

    Context 'bodies' {
        It 'assembles a flattened JSON body from bound properties only' {
            New-PetStorePet -Name 'Rex' -Status 'available' -Confirm:$false | Out-Null
            $request = Get-LastRequest
            $request.Body | Should -BeOfType [hashtable]
            @($request.Body.Keys | Sort-Object) | Should -Be @('name', 'status')
            $request.Body['name'] | Should -Be 'Rex'
            $request.ContentType | Should -Be 'application/json'
        }

        It 'sends an explicit $null body property' {
            New-PetStorePet -Name 'Rex' -Tag $null -Confirm:$false | Out-Null
            $body = (Get-LastRequest).Body
            $body.ContainsKey('tag') | Should -BeTrue
            $body['tag'] | Should -BeNullOrEmpty
        }

        It 'passes -Body as it is' {
            $body = @{ name = 'Whole' }
            New-PetStorePet -Body $body -Confirm:$false | Out-Null
            [object]::ReferenceEquals((Get-LastRequest).Body, $body) | Should -BeTrue
        }

        It 'combines path parameters and body properties with renamed names' {
            Update-StockItem -ItemId 'i1' -ItemIdBody 'b1' -Name 'n' -DebugBody -Confirm:$false | Out-Null
            $request = Get-LastRequest
            $request.PathParameters['itemId'] | Should -Be 'i1'
            $request.Body['itemId'] | Should -Be 'b1'
            $request.Body['name'] | Should -Be 'n'
            $request.Body['debug'] | Should -BeExactly $true
        }

        It 'passes complex flattened properties and the chosen content type' {
            New-ShopOrder -Quantity 5 -Rush -Labels 'a', 'b' -Address @{ city = 'c' } -LineItems @(@{ city = 'x' }) -ContentType 'application/x-www-form-urlencoded' -Confirm:$false | Out-Null
            $request = Get-LastRequest
            $request.Body['quantity'] | Should -Be 5
            $request.Body['rush'] | Should -BeExactly $true
            $request.Body['labels'] | Should -Be @('a', 'b')
            $request.Body['address']['city'] | Should -Be 'c'
            $request.Body['line-items'][0]['city'] | Should -Be 'x'
            $request.ContentType | Should -Be 'application/x-www-form-urlencoded'
        }

        It 'sends no body when an optional body has no bound property' {
            New-ShopOrder -Confirm:$false | Out-Null
            (Get-LastRequest).ContainsKey('Body') | Should -BeFalse
        }

        It 'passes form, multipart, binary, array, oneOf and text bodies through -Body' {
            Submit-ShopForm -Body @{ city = 'x' } -Confirm:$false | Out-Null
            (Get-LastRequest).ContentType | Should -Be 'application/x-www-form-urlencoded'
            (Get-LastRequest).Body['city'] | Should -Be 'x'

            New-ShopUploadFile -Body @{ file = 'a.txt' } -Confirm:$false | Out-Null
            (Get-LastRequest).ContentType | Should -Be 'multipart/form-data'

            Set-ShopFileContent -FileId 'f' -Body ([byte[]](1, 2, 3)) -Confirm:$false | Out-Null
            (Get-LastRequest).ContentType | Should -Be 'application/octet-stream'
            (Get-LastRequest).Body | Should -Be @(1, 2, 3)
            (Get-LastRequest).PathParameters['fileId'] | Should -Be 'f'

            New-ShopBatch -Body @(@{ quantity = 1 }, @{ quantity = 5 }) -Confirm:$false | Out-Null
            @((Get-LastRequest).Body).Count | Should -Be 2

            Send-ShopEvent -Body @{ city = 'x' } -Confirm:$false | Out-Null
            (Get-LastRequest).Body['city'] | Should -Be 'x'

            New-ShopNote -Body 'hello' -Confirm:$false | Out-Null
            (Get-LastRequest).ContentType | Should -Be 'text/plain'
            (Get-LastRequest).Body | Should -Be 'hello'
        }

        It 'keeps plain-text password properties' {
            New-User -Username 'u' -Password 'p' -Confirm:$false | Out-Null
            (Get-LastRequest).Body['password'] | Should -Be 'p'
        }
    }

    Context 'ShouldProcess' {
        It 'does not call the engine for <Command> with -WhatIf' -ForEach @(
            @{ Command = 'New-PetStorePet'; Arguments = @{ Name = 'Rex' } }
            @{ Command = 'Set-PetStorePet'; Arguments = @{ PetId = 'p1'; Name = 'Rex' } }
            @{ Command = 'Update-StockItem'; Arguments = @{ ItemId = 'i'; Name = 'n' } }
            @{ Command = 'Remove-PetStorePet'; Arguments = @{ PetId = 'p1' } }
        ) {
            & $Command @Arguments -WhatIf | Out-Null
            @(Get-StubCall).Count | Should -Be 0
        }

        It 'uses ConfirmImpact High for DELETE and Medium for POST' {
            (Get-Command -Name Remove-PetStorePet).ScriptBlock.Attributes.Where({ $_ -is [System.Management.Automation.CmdletBindingAttribute] })[0].ConfirmImpact | Should -Be 'High'
            (Get-Command -Name New-PetStorePet).ScriptBlock.Attributes.Where({ $_ -is [System.Management.Automation.CmdletBindingAttribute] })[0].ConfirmImpact | Should -Be 'Medium'
            (Get-Command -Name Get-PetStorePet).Parameters.ContainsKey('WhatIf') | Should -BeFalse
        }

        It 'calls the engine for DELETE after confirmation, with the header parameter' {
            Remove-PetStorePet -PetId 'p1' -ApiKey 'k' -Confirm:$false | Out-Null
            $request = Get-LastRequest
            $request.PathParameters['petId'] | Should -Be 'p1'
            $request.HeaderParameters['api_key'] | Should -Be 'k'
        }
    }

    Context 'connection commands' {
        It 'Set-<Prefix>Context calls Set-OpenApiContext with the service and the default base URI' {
            $token = New-Object -TypeName System.Security.SecureString
            Set-PetStoreContext -BearerToken $token -MaxRetries 2 | Out-Null
            $call = @(Get-StubCall)[-1]
            $call.Command | Should -Be 'Set-OpenApiContext'
            $call.Parameters['Service'] | Should -Be 'PetStore'
            $call.Parameters['BaseUri'] | Should -Be 'https://petstore.example.com/v1'
            $call.Parameters['BearerToken'] | Should -Be $token
            $call.Parameters['MaxRetries'] | Should -Be 2
            $call.Parameters.ContainsKey('WhatIf') | Should -BeFalse
        }

        It 'Set-<Prefix>Context -WhatIf changes nothing' {
            Set-PetStoreContext -WhatIf | Out-Null
            @(Get-StubCall).Count | Should -Be 0
        }

        It 'requires -BaseUri when the document has no absolute server URL' {
            (Get-Command -Name Set-ShopContext).Parameters['BaseUri'].Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] })[0].Mandatory | Should -BeTrue
            Set-ShopContext -BaseUri 'https://shop.example.com' | Out-Null
            @(Get-StubCall)[-1].Parameters['Service'] | Should -Be 'Shop'
        }

        It 'Get- and Remove-<Prefix>Context call the engine with the service' {
            Get-ReservedNamesContext | Out-Null
            @(Get-StubCall)[-1].Command | Should -Be 'Get-OpenApiContext'
            @(Get-StubCall)[-1].Parameters['Service'] | Should -Be 'Reserved.Names'
            Remove-ReservedNamesContext -Persisted -Confirm:$false | Out-Null
            @(Get-StubCall)[-1].Command | Should -Be 'Remove-OpenApiContext'
            @(Get-StubCall)[-1].Parameters['Persisted'] | Should -BeTrue
        }
    }

    Context 'Overrides.ps1' {
        It 'replaces a generated function after import and survives regeneration with -Force' {
            $overrides = Join-Path -Path $Generated['petstore'].Path -ChildPath 'Overrides.ps1'
            Add-Content -LiteralPath $overrides -Value @'

function Get-PetStoreHealth {
    [CmdletBinding()]
    param()
    'overridden'
}
'@
            Import-Module -Name $Generated['petstore'].ManifestPath -Force
            Get-PetStoreHealth | Should -Be 'overridden'
            @(Get-StubCall).Count | Should -Be 0

            # Regenerate with the real generator, then import again with the stub
            Remove-Module -Name PetStore, tcs.openapi -Force
            $env:PSModulePath = $OriginalModulePath
            Import-Module -Name $ManifestPath -Force
            $result = New-OpenApiModule -Document (New-TestOpenApiModel -Name petstore) -ModuleName 'PetStore' -NounPrefix 'PetStore' -OutputPath $OutputRoot -Force
            ($result.Files | Where-Object -FilterScript { $_.RelativePath -eq 'Overrides.ps1' }).Action | Should -Be 'Preserved'
            Remove-Module -Name tcs.openapi -Force
            $env:PSModulePath = $StubRoot + [System.IO.Path]::PathSeparator + $OriginalModulePath
            Import-Module -Name $Generated['petstore'].ManifestPath -Force
            Get-PetStoreHealth | Should -Be 'overridden'
        }
    }
}
