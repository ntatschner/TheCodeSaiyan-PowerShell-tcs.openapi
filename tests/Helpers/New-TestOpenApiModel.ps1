<#
.SYNOPSIS
    Builds hand-made document-model objects (the output shape of Import-OpenApiDocument described in
    DESIGN.md "Document model") for the generator tests, without depending on Import-OpenApiDocument.

.DESCRIPTION
    Dot-source this file in a test. New-TestSchema, New-TestParameter, New-TestRequestBody,
    New-TestResponse, New-TestOperation and New-TestDocument build single objects with every
    documented property present. New-TestOpenApiModel -Name petstore|reserved|bodies returns the
    three models used by the snapshot and generated-module tests, and Get-TestSnapshotCase the options
    they are generated with.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helpers that only build in-memory objects.')]
param()

function New-TestSchema {
    [CmdletBinding()]
    param(
        [string]$Type,
        [string]$Format,
        [switch]$Nullable,
        [object[]]$Enum,
        [object]$Default,
        [object]$Items,
        [System.Collections.IDictionary]$Properties,
        [string[]]$Required,
        [object]$AdditionalProperties,
        [object[]]$OneOf,
        [object[]]$AnyOf,
        [switch]$ReadOnly,
        [string]$Description,
        [string]$RefName,
        [string]$Pattern,
        [object]$Minimum,
        [object]$Maximum,
        [object]$MinLength,
        [object]$MaxLength,
        [object]$MinItems,
        [object]$MaxItems
    )
    $typeValue = $null
    if ($Type) { $typeValue = $Type }
    [pscustomobject]@{
        Type                 = $typeValue
        Format               = $(if ($Format) { $Format } else { $null })
        Nullable             = [bool]$Nullable
        Enum                 = $Enum
        Default              = $Default
        Const                = $null
        Items                = $Items
        Properties           = $Properties
        Required             = $Required
        AdditionalProperties = $AdditionalProperties
        AllOf                = $null
        OneOf                = $OneOf
        AnyOf                = $AnyOf
        Discriminator        = $null
        ReadOnly             = [bool]$ReadOnly
        WriteOnly            = $false
        Description          = $(if ($Description) { $Description } else { $null })
        RefName              = $(if ($RefName) { $RefName } else { $null })
        Recursive            = $false
        Pattern              = $(if ($Pattern) { $Pattern } else { $null })
        Minimum              = $Minimum
        Maximum              = $Maximum
        MinLength            = $MinLength
        MaxLength            = $MaxLength
        MinItems             = $MinItems
        MaxItems             = $MaxItems
    }
}

function New-TestParameter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('path', 'query', 'header', 'cookie')][string]$In,
        [switch]$Required,
        [object]$Schema,
        [string]$Description,
        [switch]$Deprecated,
        [string]$Style,
        [object]$Explode,
        [object]$Example,
        [switch]$CatchAll
    )
    if ($null -eq $Schema) { $Schema = New-TestSchema -Type string }
    if (-not $Style) {
        $Style = $(if ($In -eq 'query' -or $In -eq 'cookie') { 'form' } else { 'simple' })
    }
    if ($null -eq $Explode) { $Explode = ($Style -eq 'form') }
    [pscustomobject]@{
        Name          = $Name
        In            = $In
        Required      = ([bool]$Required -or $In -eq 'path')
        Description   = $(if ($Description) { $Description } else { $null })
        Deprecated    = [bool]$Deprecated
        Schema        = $Schema
        Style         = $Style
        Explode       = [bool]$Explode
        AllowReserved = $false
        Example       = $Example
        CatchAll      = [bool]$CatchAll
    }
}

function New-TestMediaType {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ContentType, [object]$Schema)
    [pscustomobject]@{ ContentType = $ContentType; Schema = $Schema; Encoding = $null }
}

function New-TestRequestBody {
    [CmdletBinding()]
    param([switch]$Required, [string]$Description, [Parameter(Mandatory)][object[]]$Content)
    [pscustomobject]@{ Required = [bool]$Required; Description = $(if ($Description) { $Description } else { $null }); Content = $Content }
}

function New-TestResponse {
    [CmdletBinding()]
    param([string]$StatusCode = '200', [string]$Description = 'OK', [object[]]$Content = @())
    [pscustomobject]@{ StatusCode = $StatusCode; Description = $Description; Content = $Content; Headers = $null }
}

function New-TestOperation {
    [CmdletBinding()]
    param(
        [string]$OperationId,
        [Parameter(Mandatory)][string]$Method,
        [Parameter(Mandatory)][string]$Path,
        [string[]]$Tags = @(),
        [string]$Summary,
        [string]$Description,
        [switch]$Deprecated,
        [string]$ExternalDocsUrl,
        [object[]]$Parameters = @(),
        [object]$RequestBody,
        [object[]]$Responses = @((New-TestResponse)),
        [object]$Security,
        [object]$Paging,
        [System.Collections.IDictionary]$Extensions = [ordered]@{},
        [switch]$Unsupported
    )
    $operation = [pscustomobject]@{
        PSTypeName      = 'Tcs.OpenApi.Operation'
        OperationId     = $OperationId
        Method          = $Method.ToUpperInvariant()
        Path            = $Path
        Tags            = $Tags
        Summary         = $(if ($Summary) { $Summary } else { $null })
        Description     = $(if ($Description) { $Description } else { $null })
        Deprecated      = [bool]$Deprecated
        ExternalDocsUrl = $(if ($ExternalDocsUrl) { $ExternalDocsUrl } else { $null })
        Parameters      = $Parameters
        RequestBody     = $RequestBody
        Responses       = $Responses
        Security        = $Security
        Paging          = $Paging
        Extensions      = $Extensions
    }
    if ($Unsupported) {
        $operation | Add-Member -NotePropertyName Unsupported -NotePropertyValue $true
    }
    $operation
}

function New-TestDocument {
    [CmdletBinding()]
    param(
        [string]$Title = 'Test API',
        [string]$Version = '1.0.0',
        [string]$Description,
        [string]$ContactUrl,
        [string]$LicenseName,
        [string]$LicenseUrl,
        [string]$ExternalDocsUrl,
        [object[]]$Servers = @(),
        [System.Collections.IDictionary]$SecuritySchemes = [ordered]@{},
        [object]$Security,
        [System.Collections.IDictionary]$Schemas = [ordered]@{},
        [object[]]$Operations = @(),
        [object[]]$Findings = @()
    )
    [pscustomobject]@{
        PSTypeName      = 'Tcs.OpenApi.Document'
        SourceVersion   = '3.0.3'
        Title           = $Title
        Version         = $Version
        Description     = $(if ($Description) { $Description } else { $null })
        ContactUrl      = $(if ($ContactUrl) { $ContactUrl } else { $null })
        LicenseName     = $(if ($LicenseName) { $LicenseName } else { $null })
        LicenseUrl      = $(if ($LicenseUrl) { $LicenseUrl } else { $null })
        ExternalDocsUrl = $(if ($ExternalDocsUrl) { $ExternalDocsUrl } else { $null })
        Servers         = $Servers
        SecuritySchemes = $SecuritySchemes
        Security        = $Security
        Schemas         = $Schemas
        Operations      = $Operations
        Findings        = $Findings
    }
}

function New-TestFinding {
    [CmdletBinding()]
    param([string]$Severity = 'Warning', [string]$Code, [string]$Pointer = '', [string]$Message = '', [string]$Operation)
    [pscustomobject]@{ PSTypeName = 'Tcs.OpenApi.Finding'; Severity = $Severity; Code = $Code; Pointer = $Pointer; Message = $Message; Operation = $Operation }
}

function Get-TestSnapshotCase {
    <#
    .SYNOPSIS
        The generator options of the three snapshot modules (tests/Snapshots/<Name>/<ModuleName>).
    #>
    [CmdletBinding()]
    param()
    @(
        [pscustomobject]@{ Name = 'petstore'; ModuleName = 'PetStore'; NounPrefix = 'PetStore' }
        [pscustomobject]@{ Name = 'reserved'; ModuleName = 'Reserved.Names'; NounPrefix = '' }
        [pscustomobject]@{ Name = 'bodies'; ModuleName = 'Shop'; NounPrefix = 'Shop' }
    )
}

function New-TestOpenApiModel {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateSet('petstore', 'reserved', 'bodies')][string]$Name)

    $json = 'application/json'
    switch ($Name) {
        'petstore' {
            $pet = New-TestSchema -Type object -RefName 'Pet' -Required @('name') -Properties ([ordered]@{
                    id     = New-TestSchema -Type integer -Format int64 -ReadOnly -Description 'The id of the pet.'
                    name   = New-TestSchema -Type string -Description 'The name of the pet.' -MinLength 1 -MaxLength 50
                    tag    = New-TestSchema -Type string -Nullable -Description 'A tag for the pet.'
                    status = New-TestSchema -Type string -Enum @('available', 'pending', 'sold') -Description 'The pet status in the store.'
                })
            $petList = New-TestSchema -Type array -Items $pet
            $operations = @(
                (New-TestOperation -OperationId 'listPets' -Method GET -Path '/pets' -Tags 'pets' -Summary 'List all pets' -Description "Returns the pets in the store.`nResults are paged." -Parameters @(
                        (New-TestParameter -Name 'limit' -In query -Description 'How many items to return at one time (max 100).' -Schema (New-TestSchema -Type integer -Format int32 -Minimum 1 -Maximum 100)),
                        (New-TestParameter -Name 'tags' -In query -Description 'Tags to filter by.' -Explode $true -Schema (New-TestSchema -Type array -Items (New-TestSchema -Type string)))
                ) -Responses @((New-TestResponse -Content @((New-TestMediaType -ContentType $json -Schema $petList)))) -Paging ([ordered]@{ Kind = 'nextLink'; ItemsProperty = 'value'; NextLinkProperty = 'nextLink' })),
                (New-TestOperation -OperationId 'createPets' -Method POST -Path '/pets' -Tags 'pets' -Summary 'Create a pet' -RequestBody (New-TestRequestBody -Required -Content @((New-TestMediaType -ContentType $json -Schema $pet))) -Responses @((New-TestResponse -StatusCode '201' -Description 'Created' -Content @((New-TestMediaType -ContentType $json -Schema $pet))))),
                (New-TestOperation -OperationId 'showPetById' -Method GET -Path '/pets/{petId}' -Tags 'pets' -Summary 'Info for a specific pet' -ExternalDocsUrl 'https://docs.example.com/pets' -Parameters @(
                        (New-TestParameter -Name 'petId' -In path -Description 'The id of the pet to retrieve.')
                ) -Responses @((New-TestResponse -Content @((New-TestMediaType -ContentType $json -Schema $pet))))),
                (New-TestOperation -OperationId 'updatePet' -Method PUT -Path '/pets/{petId}' -Tags 'pets' -Summary 'Replace a pet' -Parameters @(
                        (New-TestParameter -Name 'petId' -In path)
                ) -RequestBody (New-TestRequestBody -Required -Content @((New-TestMediaType -ContentType $json -Schema $pet))) -Responses @((New-TestResponse -Content @((New-TestMediaType -ContentType $json -Schema $pet))))),
                (New-TestOperation -OperationId 'deletePet' -Method DELETE -Path '/pets/{petId}' -Tags 'pets' -Summary 'Delete a pet' -Deprecated -Parameters @(
                        (New-TestParameter -Name 'petId' -In path),
                        (New-TestParameter -Name 'api_key' -In header)
                ) -Responses @((New-TestResponse -StatusCode '204' -Description 'Deleted'))),
                (New-TestOperation -OperationId 'getPetPhoto' -Method GET -Path '/pets/{petId}/photo' -Tags 'pets' -Summary 'Download the photo of a pet' -Parameters @(
                        (New-TestParameter -Name 'petId' -In path)
                ) -Responses @((New-TestResponse -Content @((New-TestMediaType -ContentType 'image/png' -Schema (New-TestSchema -Type string -Format binary)))))),
                (New-TestOperation -OperationId 'petStats' -Method GET -Path '/pets/stats' -Tags 'pets' -Summary 'Pet statistics' -Extensions ([ordered]@{ 'x-ps-name' = 'Measure-PetStatistic' }) -Responses @((New-TestResponse -Content @((New-TestMediaType -ContentType $json -Schema (New-TestSchema -Type object)))))),
                (New-TestOperation -OperationId 'getInventory' -Method GET -Path '/store/inventory' -Tags 'store' -Summary 'Returns pet inventories by status' -Security @([ordered]@{ api_key = @() }) -Responses @((New-TestResponse -Content @((New-TestMediaType -ContentType $json -Schema (New-TestSchema -Type object -AdditionalProperties (New-TestSchema -Type integer))))))),
                (New-TestOperation -OperationId 'getHealth' -Method GET -Path '/health' -Security @() -Responses @((New-TestResponse -Content @((New-TestMediaType -ContentType 'text/plain' -Schema (New-TestSchema -Type string))))))
            )
            return New-TestDocument -Title 'Swagger Petstore' -Version '1.0.0' -Description 'A sample API that uses a petstore as an example.' -Servers @(
                [pscustomobject]@{ Url = 'https://petstore.example.com/{version}'; Description = 'Production'; Variables = [ordered]@{ version = [pscustomobject]@{ Default = 'v1'; Enum = @('v1', 'v2') } } }
            ) -SecuritySchemes ([ordered]@{
                    api_key = [pscustomobject]@{ Name = 'api_key'; Type = 'apiKey'; In = 'header'; ParameterName = 'api_key'; Scheme = $null; BearerFormat = $null; Flows = $null }
                    bearer  = [pscustomobject]@{ Name = 'bearer'; Type = 'http'; In = $null; ParameterName = $null; Scheme = 'bearer'; BearerFormat = 'JWT'; Flows = $null }
                }) -Security @([ordered]@{ bearer = @() }) -Schemas ([ordered]@{ Pet = $pet }) -Operations $operations -Findings @(
                (New-TestFinding -Severity Warning -Code 'OA010' -Pointer '/paths/~1health/get' -Message 'The operation has no operationId; generated getHealth.' -Operation 'getHealth')
            )
        }
        'reserved' {
            $itemBody = New-TestSchema -Type object -Required @('name') -Properties ([ordered]@{
                    itemId = New-TestSchema -Type string
                    name   = New-TestSchema -Type string
                    debug  = New-TestSchema -Type boolean
                })
            $userBody = New-TestSchema -Type object -Required @('username', 'password') -Properties ([ordered]@{
                    username = New-TestSchema -Type string
                    password = New-TestSchema -Type string -Format password
                })
            $operations = @(
                (New-TestOperation -OperationId 'getStockItem' -Method GET -Path '/items/{itemId}' -Tags 'items' -Summary 'Get an item from stock' -Parameters @(
                        (New-TestParameter -Name 'itemId' -In path),
                        (New-TestParameter -Name 'debug' -In query -Schema (New-TestSchema -Type boolean) -Description 'Adds debug output.'),
                        (New-TestParameter -Name 'Raw' -In query),
                        (New-TestParameter -Name 'user_id' -In query),
                        (New-TestParameter -Name 'userId' -In query),
                        (New-TestParameter -Name '$filter' -In query),
                        (New-TestParameter -Name 'page[size]' -In query -Schema (New-TestSchema -Type integer)),
                        (New-TestParameter -Name 'X-Request-Id' -In header -Required),
                        (New-TestParameter -Name 'Host' -In header),
                        (New-TestParameter -Name 'X-Strict' -In header -Required -Schema (New-TestSchema -Type boolean)),
                        (New-TestParameter -Name 'session_id' -In cookie)
                )),
                (New-TestOperation -OperationId 'updateStockItem' -Method PATCH -Path '/items/{itemId}' -Tags 'items' -Parameters @(
                        (New-TestParameter -Name 'itemId' -In path)
                ) -RequestBody (New-TestRequestBody -Required -Content @((New-TestMediaType -ContentType $json -Schema $itemBody)))),
                (New-TestOperation -OperationId 'getPetOwner' -Method GET -Path '/pets/{petId}/owner' -Tags 'owners' -Parameters @((New-TestParameter -Name 'petId' -In path))),
                (New-TestOperation -OperationId 'get_pet_owner' -Method GET -Path '/pets/owner/{name}' -Tags 'owners' -Parameters @((New-TestParameter -Name 'name' -In path))),
                (New-TestOperation -OperationId 'setThing' -Method PUT -Path '/things' -Tags 'things'),
                (New-TestOperation -OperationId 'putThing' -Method POST -Path '/things' -Tags 'things'),
                (New-TestOperation -OperationId 'fetchWidget' -Method GET -Path '/widgets' -Extensions ([ordered]@{ 'x-ps-verb' = 'Fetch'; 'x-ps-noun' = 'Gadget' })),
                (New-TestOperation -OperationId 'getMetadata' -Method GET -Path '/metadata'),
                (New-TestOperation -OperationId 'createUser' -Method POST -Path '/users' -Tags 'users' -RequestBody (New-TestRequestBody -Required -Content @((New-TestMediaType -ContentType $json -Schema $userBody)))),
                (New-TestOperation -OperationId 'getRemote' -Method GET -Path '/remote' -Unsupported)
            )
            return New-TestDocument -Title 'Reserved Names API' -Version '2.1' -Servers @() -Operations $operations -Findings @(
                (New-TestFinding -Severity Error -Code 'OA020' -Pointer '/paths/~1remote/get' -Message 'External $ref.' -Operation 'getRemote')
            )
        }
        'bodies' {
            $address = New-TestSchema -Type object -RefName 'Address' -Properties ([ordered]@{ city = New-TestSchema -Type string })
            # Nested references inside a named schema are stubs: RefName and scalar keywords only
            $addressStub = New-TestSchema -Type object -RefName 'Address'
            $untypedAddressStub = New-TestSchema -RefName 'Address'
            $order = New-TestSchema -Type object -RefName 'Order' -Properties ([ordered]@{
                    id           = New-TestSchema -Type string -ReadOnly
                    quantity     = New-TestSchema -Type integer -Format int32 -Enum @(1, 5, 10)
                    total        = New-TestSchema -Type number -Minimum 0 -Maximum 10000.5
                    rush         = New-TestSchema -Type boolean
                    shipDate     = New-TestSchema -Type string -Format date-time
                    note         = New-TestSchema -Type string -Nullable -Pattern '^[a-z ]*$'
                    labels       = New-TestSchema -Type array -Items (New-TestSchema -Type string) -MaxItems 5
                    address      = $addressStub
                    'line-items' = New-TestSchema -Type array -Items $untypedAddressStub
                })
            $operations = @(
                (New-TestOperation -OperationId 'submitForm' -Method POST -Path '/forms' -Tags 'forms' -RequestBody (New-TestRequestBody -Required -Content @((New-TestMediaType -ContentType 'application/x-www-form-urlencoded' -Schema $address)))),
                (New-TestOperation -OperationId 'uploadFile' -Method POST -Path '/files' -Tags 'files' -RequestBody (New-TestRequestBody -Content @((New-TestMediaType -ContentType 'multipart/form-data' -Schema (New-TestSchema -Type object -Properties ([ordered]@{ file = New-TestSchema -Type string -Format binary })))))),
                (New-TestOperation -OperationId 'putFileContent' -Method PUT -Path '/files/{fileId}/content' -Tags 'files' -Parameters @((New-TestParameter -Name 'fileId' -In path)) -RequestBody (New-TestRequestBody -Required -Content @((New-TestMediaType -ContentType 'application/octet-stream' -Schema (New-TestSchema -Type string -Format binary))))),
                (New-TestOperation -OperationId 'downloadFile' -Method GET -Path '/files/{fileId}' -Tags 'files' -Parameters @((New-TestParameter -Name 'fileId' -In path)) -Responses @((New-TestResponse -Content @((New-TestMediaType -ContentType 'application/octet-stream' -Schema (New-TestSchema -Type string -Format binary)))))),
                (New-TestOperation -OperationId 'createBatch' -Method POST -Path '/batch' -Tags 'orders' -RequestBody (New-TestRequestBody -Required -Content @((New-TestMediaType -ContentType $json -Schema (New-TestSchema -Type array -Items $order))))),
                (New-TestOperation -OperationId 'sendEvent' -Method POST -Path '/events' -RequestBody (New-TestRequestBody -Required -Content @((New-TestMediaType -ContentType $json -Schema (New-TestSchema -OneOf @($order, $address)))))),
                (New-TestOperation -OperationId 'createOrder' -Method POST -Path '/orders' -Tags 'orders' -Summary 'Place an order' -RequestBody (New-TestRequestBody -Content @((New-TestMediaType -ContentType $json -Schema $order), (New-TestMediaType -ContentType 'application/x-www-form-urlencoded' -Schema $order))) -Responses @((New-TestResponse -StatusCode '201' -Content @((New-TestMediaType -ContentType $json -Schema $order))))),
                (New-TestOperation -OperationId 'listOrders' -Method GET -Path '/orders' -Tags 'orders' -Summary 'List orders' -Parameters @(
                        (New-TestParameter -Name 'since' -In query -Schema (New-TestSchema -Type string -Format date-time)),
                        (New-TestParameter -Name 'status' -In query -Schema (New-TestSchema -Type array -Items (New-TestSchema -Type string -Enum @('open', 'closed')))),
                        (New-TestParameter -Name 'include_deleted' -In query -Schema (New-TestSchema -Type boolean)),
                        (New-TestParameter -Name 'min_total' -In query -Schema (New-TestSchema -Type number))
                ) -Responses @((New-TestResponse -Content @((New-TestMediaType -ContentType $json -Schema (New-TestSchema -Type array -Items $order))))) -Paging ([ordered]@{ Kind = 'linkHeader'; ItemsProperty = $null; NextLinkProperty = $null })),
                (New-TestOperation -OperationId 'getReport' -Method GET -Path '/reports/{reportId}' -Tags 'reports' -Parameters @((New-TestParameter -Name 'reportId' -In path -Schema (New-TestSchema -Type integer -Format int64))) -Responses @((New-TestResponse -Content @((New-TestMediaType -ContentType 'application/pdf' -Schema (New-TestSchema -Type string -Format binary)))))),
                (New-TestOperation -OperationId 'createNote' -Method POST -Path '/notes' -Tags 'notes' -Summary "Créer une note (non-ASCII summary)" -RequestBody (New-TestRequestBody -Required -Content @((New-TestMediaType -ContentType 'text/plain' -Schema (New-TestSchema -Type string))))),
                (New-TestOperation -OperationId 'getPublicStatus' -Method GET -Path '/public/status' -Security @())
            )
            return New-TestDocument -Title 'Bodies API' -Version '3.0' -Servers @([pscustomobject]@{ Url = '/api'; Description = $null; Variables = $null }) -SecuritySchemes ([ordered]@{
                    oauth = [pscustomobject]@{ Name = 'oauth'; Type = 'oauth2'; In = $null; ParameterName = $null; Scheme = $null; BearerFormat = $null; Flows = [ordered]@{ clientCredentials = [pscustomobject]@{ TokenUrl = 'https://auth.example.com/token'; Scopes = [ordered]@{ 'orders.read' = 'Read orders' } } } }
                }) -Security @([ordered]@{ oauth = @('orders.read') }) -Schemas ([ordered]@{ Address = $address; Order = $order }) -Operations $operations
        }
    }
}
