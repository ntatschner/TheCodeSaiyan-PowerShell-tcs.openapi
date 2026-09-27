BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/New-TestOpenApiModel.ps1')
}

Describe 'ConvertTo-OpenApiGenMetadataEntry' {
    BeforeAll {
        $document = New-TestOpenApiModel -Name petstore
        function Get-TestMetadata {
            param($Operation, $Document, [string]$UnwrapProperty)
            InModuleScope tcs.openapi -Parameters @{ Operation = $Operation; Document = $Document; UnwrapProperty = $UnwrapProperty } {
                param($Operation, $Document, $UnwrapProperty)
                ConvertTo-OpenApiGenMetadataEntry -Operation $Operation -Document $Document -Service 'PetStore' -UnwrapProperty $UnwrapProperty
            }
        }
    }

    It 'has the documented properties in order' {
        $metadata = Get-TestMetadata -Operation $document.Operations[0] -Document $document
        @($metadata.Keys) | Should -Be @('OperationId', 'Method', 'Path', 'Service', 'Deprecated', 'Parameters', 'RequestContentTypes', 'ResponseContentTypes', 'BinaryResponse', 'Security', 'SecuritySchemes', 'Paging', 'ResponseTypeName')
    }

    It 'copies the spec parameters with style and explode' {
        $metadata = Get-TestMetadata -Operation $document.Operations[0] -Document $document
        $metadata.OperationId | Should -Be 'listPets'
        $metadata.Service | Should -Be 'PetStore'
        $metadata.Parameters.Count | Should -Be 2
        $metadata.Parameters[1].Name | Should -Be 'tags'
        $metadata.Parameters[1].In | Should -Be 'query'
        $metadata.Parameters[1].Style | Should -Be 'form'
        $metadata.Parameters[1].Explode | Should -BeTrue
        $metadata.Parameters[1].AllowReserved | Should -BeFalse
        @($metadata.Parameters[1].Keys) | Should -Be @('Name', 'In', 'Style', 'Explode', 'AllowReserved')
    }

    It 'defaults style and explode by location when missing' {
        $parameter = New-TestParameter -Name 'id' -In path
        $parameter.Style = $null
        $parameter.Explode = $null
        $operation = New-TestOperation -OperationId 'x' -Method GET -Path '/x/{id}' -Parameters @($parameter)
        $metadata = Get-TestMetadata -Operation $operation -Document $document
        $metadata.Parameters[0].Style | Should -Be 'simple'
        $metadata.Parameters[0].Explode | Should -BeFalse
    }

    It 'sets the response type name from the array item schema' {
        (Get-TestMetadata -Operation $document.Operations[0] -Document $document).ResponseTypeName | Should -Be 'PetStore.Pet'
    }

    It 'types the items of a nextLink page, looking the page schema up when it is a stub' {
        $itemStub = New-TestSchema -Type object -RefName 'Pet'
        $page = New-TestSchema -Type object -RefName 'PetPage' -Properties ([ordered]@{
                value    = New-TestSchema -Type array -Items $itemStub
                nextLink = New-TestSchema -Type string
            })
        $paging = [ordered]@{ Kind = 'nextLink'; ItemsProperty = 'value'; NextLinkProperty = 'nextLink' }
        $json = 'application/json'
        $full = New-TestOperation -OperationId 'listFull' -Method GET -Path '/full' -Paging $paging -Responses @((New-TestResponse -Content @((New-TestMediaType -ContentType $json -Schema $page))))
        (Get-TestMetadata -Operation $full -Document $document).ResponseTypeName | Should -Be 'PetStore.Pet'

        $withPage = New-TestDocument -Schemas ([ordered]@{ PetPage = $page })
        $stubbed = New-TestOperation -OperationId 'listStub' -Method GET -Path '/stub' -Paging $paging -Responses @((New-TestResponse -Content @((New-TestMediaType -ContentType $json -Schema (New-TestSchema -Type object -RefName 'PetPage')))))
        (Get-TestMetadata -Operation $stubbed -Document $withPage).ResponseTypeName | Should -Be 'PetStore.Pet'

        $untyped = New-TestSchema -Type object -Properties ([ordered]@{ value = New-TestSchema -Type array -Items (New-TestSchema -Type object) })
        $plain = New-TestOperation -OperationId 'listPlain' -Method GET -Path '/plain' -Paging $paging -Responses @((New-TestResponse -Content @((New-TestMediaType -ContentType $json -Schema $untyped))))
        (Get-TestMetadata -Operation $plain -Document $document).ResponseTypeName | Should -BeNullOrEmpty
    }

    It 'detects binary responses' {
        $photo = $document.Operations | Where-Object -FilterScript { $_.OperationId -eq 'getPetPhoto' }
        $metadata = Get-TestMetadata -Operation $photo -Document $document
        $metadata.BinaryResponse | Should -BeTrue
        $metadata.ResponseContentTypes | Should -Be @('image/png')
        $metadata.ResponseTypeName | Should -BeNullOrEmpty
    }

    It 'uses the document security when the operation has none, with the schemes it names' {
        $metadata = Get-TestMetadata -Operation $document.Operations[0] -Document $document
        $metadata.Security.Count | Should -Be 1
        @($metadata.Security[0].Keys) | Should -Be @('bearer')
        @($metadata.SecuritySchemes.Keys) | Should -Be @('bearer')
        $metadata.SecuritySchemes['bearer'].Scheme | Should -Be 'bearer'
    }

    It 'keeps the operation security and an empty list' {
        $inventory = $document.Operations | Where-Object -FilterScript { $_.OperationId -eq 'getInventory' }
        @((Get-TestMetadata -Operation $inventory -Document $document).SecuritySchemes.Keys) | Should -Be @('api_key')
        $health = $document.Operations | Where-Object -FilterScript { $_.OperationId -eq 'getHealth' }
        $metadata = Get-TestMetadata -Operation $health -Document $document
        , $metadata.Security | Should -BeOfType [object[]]
        $metadata.Security.Count | Should -Be 0
        $metadata.SecuritySchemes.Count | Should -Be 0
    }

    It 'keeps null security when neither the operation nor the document has one' {
        $plain = New-TestDocument -Operations @((New-TestOperation -OperationId 'x' -Method GET -Path '/x'))
        (Get-TestMetadata -Operation $plain.Operations[0] -Document $plain).Security | Should -BeNullOrEmpty
    }

    It 'copies request content types and paging' {
        $create = $document.Operations | Where-Object -FilterScript { $_.OperationId -eq 'createPets' }
        (Get-TestMetadata -Operation $create -Document $document).RequestContentTypes | Should -Be @('application/json')
        (Get-TestMetadata -Operation $document.Operations[0] -Document $document).Paging.Kind | Should -Be 'nextLink'
    }

    It 'writes CatchAll only for a catch-all path parameter' {
        $operation = New-TestOperation -OperationId 'proxy' -Method GET -Path '/c/{id}/{path}' -Parameters @((New-TestParameter -Name 'id' -In path), (New-TestParameter -Name 'path' -In path -CatchAll))
        $metadata = Get-TestMetadata -Operation $operation -Document $document
        @($metadata.Parameters[0].Keys) | Should -Be @('Name', 'In', 'Style', 'Explode', 'AllowReserved')
        @($metadata.Parameters[1].Keys) | Should -Be @('Name', 'In', 'Style', 'Explode', 'AllowReserved', 'CatchAll')
        $metadata.Parameters[1].CatchAll | Should -BeTrue
    }

    It 'copies token paging' {
        $paging = [pscustomobject]@{ PSTypeName = 'Tcs.OpenApi.Paging'; Kind = 'token'; ItemsProperty = 'data'; TokenParameter = 'nextToken'; TokenProperty = 'nextToken' }
        $page = New-TestSchema -Type object -Properties ([ordered]@{ data = New-TestSchema -Type array -Items (New-TestSchema -Type object -RefName 'Host'); nextToken = New-TestSchema -Type string })
        $operation = New-TestOperation -OperationId 'listHosts' -Method GET -Path '/hosts' -Paging $paging -Responses @((New-TestResponse -Content @((New-TestMediaType -ContentType 'application/json' -Schema $page))))
        $metadata = Get-TestMetadata -Operation $operation -Document $document -UnwrapProperty 'data'
        $metadata.Paging.Kind | Should -Be 'token'
        $metadata.Paging.TokenParameter | Should -Be 'nextToken'
        $metadata.ResponseTypeName | Should -Be 'PetStore.Host'
        # A pageable operation outputs its items already: no UnwrapProperty
        $metadata.Contains('UnwrapProperty') | Should -BeFalse
    }

    It 'sets UnwrapProperty and types the unwrapped value when the 2xx JSON object has that property' {
        $json = 'application/json'
        $wrapped = New-TestSchema -Type object -Properties ([ordered]@{ data = New-TestSchema -Type object -RefName 'Host'; traceId = New-TestSchema -Type string })
        $operation = New-TestOperation -OperationId 'getHost' -Method GET -Path '/hosts/{id}' -Responses @((New-TestResponse -Content @((New-TestMediaType -ContentType $json -Schema $wrapped))))
        $metadata = Get-TestMetadata -Operation $operation -Document $document -UnwrapProperty 'data'
        @($metadata.Keys)[-1] | Should -Be 'UnwrapProperty'
        $metadata.UnwrapProperty | Should -Be 'data'
        $metadata.ResponseTypeName | Should -Be 'PetStore.Host'

        $list = New-TestSchema -Type object -Properties ([ordered]@{ data = New-TestSchema -Type array -Items (New-TestSchema -Type object -RefName 'Config') })
        $listOperation = New-TestOperation -OperationId 'listConfigs' -Method GET -Path '/configs' -Responses @((New-TestResponse -Content @((New-TestMediaType -ContentType $json -Schema $list))))
        (Get-TestMetadata -Operation $listOperation -Document $document -UnwrapProperty 'data').ResponseTypeName | Should -Be 'PetStore.Config'

        # The wrapper's own name is not used for the unwrapped value
        $named = New-TestSchema -Type object -RefName 'Envelope' -Properties ([ordered]@{ data = New-TestSchema -Type object })
        $namedOperation = New-TestOperation -OperationId 'getEnvelope' -Method GET -Path '/e' -Responses @((New-TestResponse -Content @((New-TestMediaType -ContentType $json -Schema $named))))
        $namedMetadata = Get-TestMetadata -Operation $namedOperation -Document $document -UnwrapProperty 'data'
        $namedMetadata.UnwrapProperty | Should -Be 'data'
        $namedMetadata.ResponseTypeName | Should -BeNullOrEmpty
    }

    It 'leaves UnwrapProperty out when the response has no such property' {
        $plain = New-TestSchema -Type object -Properties ([ordered]@{ success = New-TestSchema -Type boolean })
        $operation = New-TestOperation -OperationId 'post' -Method POST -Path '/p' -Responses @((New-TestResponse -Content @((New-TestMediaType -ContentType 'application/json' -Schema $plain))))
        (Get-TestMetadata -Operation $operation -Document $document -UnwrapProperty 'data').Contains('UnwrapProperty') | Should -BeFalse
        (Get-TestMetadata -Operation $document.Operations[1] -Document $document).Contains('UnwrapProperty') | Should -BeFalse
    }
}
