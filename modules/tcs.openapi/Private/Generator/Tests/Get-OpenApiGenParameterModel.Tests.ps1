BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/New-TestOpenApiModel.ps1')
}

Describe 'Get-OpenApiGenParameterModel' {
    BeforeAll {
        function Get-TestModel {
            param($Operation, [string]$BaseNoun = '')
            InModuleScope tcs.openapi -Parameters @{ Operation = $Operation; BaseNoun = $BaseNoun } {
                param($Operation, $BaseNoun)
                Get-OpenApiGenParameterModel -Operation $Operation -BaseNoun $BaseNoun
            }
        }
        function Get-TestParameter {
            param($Model, [string]$Name)
            @($Model.Parameters | Where-Object -FilterScript { $_.Name -eq $Name })[0]
        }
    }

    It 'uses PascalCase names and keeps the spec name' {
        $model = Get-TestModel -Operation (New-TestOperation -OperationId 'x' -Method GET -Path '/x/{user_id}' -Parameters @(
                (New-TestParameter -Name 'user_id' -In path),
                (New-TestParameter -Name 'X-Request-Id' -In header)
            ))
        $user = Get-TestParameter $model 'UserId'
        $user.SpecName | Should -Be 'user_id'
        $user.In | Should -Be 'path'
        $user.Mandatory | Should -BeTrue
        $user.Aliases | Should -Be @('user_id')
        (Get-TestParameter $model 'XRequestId').Aliases | Should -Be @('X-Request-Id')
        (Get-TestParameter $model 'XRequestId').Mandatory | Should -BeFalse
    }

    It 'orders spec parameters path, query, header, cookie and ends with -Raw' {
        $model = Get-TestModel -Operation (New-TestOperation -OperationId 'x' -Method GET -Path '/x/{id}' -Parameters @(
                (New-TestParameter -Name 'c' -In cookie),
                (New-TestParameter -Name 'h' -In header),
                (New-TestParameter -Name 'q' -In query),
                (New-TestParameter -Name 'id' -In path)
            ))
        $model.Parameters.Name | Should -Be @('Id', 'Q', 'H', 'C', 'Raw')
    }

    It 'renames parameters that clash with <Name> and reports OA041' -TestCases @(
        @{ Name = 'debug'; In = 'query'; Expected = 'DebugQuery' }
        @{ Name = 'ErrorAction'; In = 'header'; Expected = 'ErrorActionHeader' }
        @{ Name = 'raw'; In = 'query'; Expected = 'RawQuery' }
        @{ Name = 'all'; In = 'query'; Expected = 'AllQuery' }
        @{ Name = 'body'; In = 'query'; Expected = 'BodyQuery' }
        @{ Name = 'content-type'; In = 'header'; Expected = 'ContentTypeHeader' }
        @{ Name = 'OutFile'; In = 'query'; Expected = 'OutFileQuery' }
        @{ Name = 'Host'; In = 'header'; Expected = 'HostHeader' }
        @{ Name = 'input'; In = 'query'; Expected = 'InputQuery' }
        @{ Name = 'whatIf'; In = 'cookie'; Expected = 'WhatIfCookie' }
    ) {
        param($Name, $In, $Expected)
        $model = Get-TestModel -Operation (New-TestOperation -OperationId 'x' -Method GET -Path '/x' -Parameters @((New-TestParameter -Name $Name -In $In)))
        $model.Parameters[0].Name | Should -BeExactly $Expected
        $model.Findings.Count | Should -Be 1
        $model.Findings[0].Code | Should -Be 'OA041'
        $model.Findings[0].Severity | Should -Be 'Warning'
    }

    It 'gives the second of two parameters with one name a suffix, then a number' {
        $model = Get-TestModel -Operation (New-TestOperation -OperationId 'x' -Method GET -Path '/x' -Parameters @(
                (New-TestParameter -Name 'user_id' -In query),
                (New-TestParameter -Name 'userId' -In query),
                (New-TestParameter -Name 'user-id' -In query),
                (New-TestParameter -Name 'USER_ID' -In header)
            ))
        $model.Parameters.Name | Should -Be @('UserId', 'UserIdQuery', 'UserIdQuery2', 'UserIdHeader', 'Raw')
        $model.Findings.Count | Should -Be 3
    }

    It 'does not add an alias that is taken by another name or a common parameter alias' {
        $model = Get-TestModel -Operation (New-TestOperation -OperationId 'x' -Method GET -Path '/x' -Parameters @(
                (New-TestParameter -Name 'user_id' -In query),
                (New-TestParameter -Name 'userId' -In header),
                (New-TestParameter -Name 'ea' -In query),
                (New-TestParameter -Name '$filter' -In query)
            ))
        (Get-TestParameter $model 'UserIdHeader').Aliases.Count | Should -Be 0
        (Get-TestParameter $model 'Ea').Aliases.Count | Should -Be 0
        (Get-TestParameter $model 'Filter').Aliases.Count | Should -Be 0
    }

    It 'adds the Id alias to the path parameter named after the noun' {
        $model = Get-TestModel -Operation (New-TestOperation -OperationId 'x' -Method GET -Path '/pets/{petId}/toys/{toyId}' -Parameters @(
                (New-TestParameter -Name 'petId' -In path),
                (New-TestParameter -Name 'toyId' -In path)
            )) -BaseNoun 'PetToy'
        (Get-TestParameter $model 'PetId').Aliases | Should -Be @()
        (Get-TestParameter $model 'ToyId').Aliases | Should -Be @('Id')
    }

    It 'uses [switch] for an optional query boolean and [bool] for a required header boolean' {
        $model = Get-TestModel -Operation (New-TestOperation -OperationId 'x' -Method GET -Path '/x' -Parameters @(
                (New-TestParameter -Name 'verbose_output' -In query -Schema (New-TestSchema -Type boolean)),
                (New-TestParameter -Name 'strict' -In header -Required -Schema (New-TestSchema -Type boolean))
            ))
        (Get-TestParameter $model 'VerboseOutput').TypeName | Should -Be 'switch'
        (Get-TestParameter $model 'Strict').TypeName | Should -Be 'bool'
        (Get-TestParameter $model 'Strict').Mandatory | Should -BeTrue
    }

    It 'flattens a JSON object body and adds -Body in its own parameter set' {
        $schema = New-TestSchema -Type object -Required @('name') -Properties ([ordered]@{
                id   = New-TestSchema -Type integer -ReadOnly
                name = New-TestSchema -Type string
                tags = New-TestSchema -Type array -Items (New-TestSchema -Type string)
                meta = New-TestSchema -Type object
            })
        $model = Get-TestModel -Operation (New-TestOperation -OperationId 'x' -Method POST -Path '/x' -RequestBody (New-TestRequestBody -Required -Content @((New-TestMediaType -ContentType 'application/json' -Schema $schema))))
        $model.BodyMode | Should -Be 'Flattened'
        $model.BodyRequired | Should -BeTrue
        $model.Parameters.Name | Should -Be @('Name', 'Tags', 'Meta', 'Body', 'Raw')
        (Get-TestParameter $model 'Name').Mandatory | Should -BeTrue
        (Get-TestParameter $model 'Name').ParameterSet | Should -Be 'Parameters'
        (Get-TestParameter $model 'Name').In | Should -Be 'body'
        (Get-TestParameter $model 'Tags').Mandatory | Should -BeFalse
        (Get-TestParameter $model 'Meta').TypeName | Should -Be 'hashtable'
        (Get-TestParameter $model 'Body').ParameterSet | Should -Be 'Body'
        (Get-TestParameter $model 'Body').TypeName | Should -Be 'object'
        (Get-TestParameter $model 'Body').Mandatory | Should -BeTrue
    }

    It 'makes body properties optional when the body is optional' {
        $schema = New-TestSchema -Type object -Required @('name') -Properties ([ordered]@{ name = New-TestSchema -Type string })
        $model = Get-TestModel -Operation (New-TestOperation -OperationId 'x' -Method POST -Path '/x' -RequestBody (New-TestRequestBody -Content @((New-TestMediaType -ContentType 'application/json' -Schema $schema))))
        (Get-TestParameter $model 'Name').Mandatory | Should -BeFalse
        (Get-TestParameter $model 'Body').Mandatory | Should -BeFalse
    }

    It 'gives <Kind> bodies only -Body of type <Type>' -TestCases @(
        @{ Kind = 'form'; ContentType = 'application/x-www-form-urlencoded'; Schema = 'object'; Type = 'hashtable' }
        @{ Kind = 'multipart'; ContentType = 'multipart/form-data'; Schema = 'object'; Type = 'hashtable' }
        @{ Kind = 'binary'; ContentType = 'application/octet-stream'; Schema = 'binary'; Type = 'object' }
        @{ Kind = 'array'; ContentType = 'application/json'; Schema = 'array'; Type = 'object' }
        @{ Kind = 'text'; ContentType = 'text/plain'; Schema = 'string'; Type = 'object' }
        @{ Kind = 'oneOf'; ContentType = 'application/json'; Schema = 'oneOf'; Type = 'object' }
    ) {
        param($Kind, $ContentType, $Schema, $Type)
        $schemaObject = switch ($Schema) {
            'object' { New-TestSchema -Type object -Properties ([ordered]@{ a = New-TestSchema -Type string }) }
            'binary' { New-TestSchema -Type string -Format binary }
            'array' { New-TestSchema -Type array -Items (New-TestSchema -Type string) }
            'string' { New-TestSchema -Type string }
            'oneOf' { New-TestSchema -OneOf @((New-TestSchema -Type object -Properties ([ordered]@{ a = New-TestSchema -Type string }))) }
        }
        $model = Get-TestModel -Operation (New-TestOperation -OperationId 'x' -Method POST -Path '/x' -RequestBody (New-TestRequestBody -Required -Content @((New-TestMediaType -ContentType $ContentType -Schema $schemaObject))))
        $model.BodyMode | Should -Be 'Body'
        $model.Parameters.Name | Should -Be @('Body', 'Raw')
        (Get-TestParameter $model 'Body').TypeName | Should -Be $Type
        (Get-TestParameter $model 'Body').ParameterSet | Should -BeNullOrEmpty
    }

    It 'suffixes a body property that clashes with a path parameter' {
        $schema = New-TestSchema -Type object -Properties ([ordered]@{ petId = New-TestSchema -Type string })
        $model = Get-TestModel -Operation (New-TestOperation -OperationId 'x' -Method PATCH -Path '/pets/{petId}' -Parameters @((New-TestParameter -Name 'petId' -In path)) -RequestBody (New-TestRequestBody -Content @((New-TestMediaType -ContentType 'application/json' -Schema $schema))))
        $model.Parameters.Name | Should -Be @('PetId', 'PetIdBody', 'Body', 'Raw')
        $model.Findings[0].Code | Should -Be 'OA041'
    }

    It 'adds -ContentType when the body has several media types' {
        $schema = New-TestSchema -Type object -Properties ([ordered]@{ a = New-TestSchema -Type string })
        $model = Get-TestModel -Operation (New-TestOperation -OperationId 'x' -Method POST -Path '/x' -RequestBody (New-TestRequestBody -Content @((New-TestMediaType -ContentType 'application/json' -Schema $schema), (New-TestMediaType -ContentType 'application/xml' -Schema $schema))))
        $model.ContentTypes | Should -Be @('application/json', 'application/xml')
        (Get-TestParameter $model 'ContentType').Attributes | Should -Be @("[ValidateSet('application/json', 'application/xml')]")
    }

    It 'adds -All for pageable operations and -OutFile for binary responses' {
        $operation = New-TestOperation -OperationId 'x' -Method GET -Path '/x' -Paging ([ordered]@{ Kind = 'nextLink' }) -Responses @((New-TestResponse -Content @((New-TestMediaType -ContentType 'application/pdf' -Schema (New-TestSchema -Type string -Format binary)))))
        $model = Get-TestModel -Operation $operation
        $model.Parameters.Name | Should -Be @('All', 'OutFile', 'Raw')
        $model.Pageable | Should -BeTrue
        $model.BinaryResponse | Should -BeTrue
        (Get-TestParameter $model 'All').TypeName | Should -Be 'switch'
        (Get-TestParameter $model 'OutFile').TypeName | Should -Be 'string'
    }

    It 'does not add -OutFile for JSON or error-only binary responses' {
        $operation = New-TestOperation -OperationId 'x' -Method GET -Path '/x' -Responses @(
            (New-TestResponse -Content @((New-TestMediaType -ContentType 'application/json' -Schema (New-TestSchema -Type object)))),
            (New-TestResponse -StatusCode 'default' -Content @((New-TestMediaType -ContentType 'application/octet-stream')))
        )
        (Get-TestModel -Operation $operation).Parameters.Name | Should -Be @('Raw')
    }

    It 'marks spec and body parameters for pipeline input by property name only' {
        $schema = New-TestSchema -Type object -Properties ([ordered]@{ a = New-TestSchema -Type string })
        $model = Get-TestModel -Operation (New-TestOperation -OperationId 'x' -Method POST -Path '/x/{id}' -Parameters @((New-TestParameter -Name 'id' -In path)) -RequestBody (New-TestRequestBody -Content @((New-TestMediaType -ContentType 'application/json' -Schema $schema))))
        ($model.Parameters | Where-Object -FilterScript { $_.Pipeline }).Name | Should -Be @('Id', 'A')
    }
}
