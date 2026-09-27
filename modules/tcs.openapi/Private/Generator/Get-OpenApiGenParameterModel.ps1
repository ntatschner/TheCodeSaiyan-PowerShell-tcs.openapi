function Get-OpenApiGenParameterModel {
    <#
    .SYNOPSIS
        Builds the PowerShell parameter list of the wrapper for one operation.

    .DESCRIPTION
        Spec parameters (path, query, header, cookie), then the request body: a JSON object body is
        flattened into one parameter per writable top-level property (parameter set 'Parameters')
        plus -Body (parameter set 'Body'); any other body gets only -Body. Then -ContentType (when the
        body has more than one media type), -All (pageable), -OutFile (binary response) and -Raw.

        Names are the PascalCase spec names. A name that clashes with a common parameter, a wrapper
        parameter (All, Raw, OutFile, Body, ContentType), an automatic variable or a variable the
        wrapper uses gets the location as a suffix ('DebugQuery'); a name already used by an earlier
        parameter gets the suffix too, then a number. Every rename is an OA041 warning.
        Aliases: the spec name when it differs, and 'Id' for a path parameter named <noun>Id.

        -Schemas (Document.Schemas) is used to look up schema stubs (see Resolve-OpenApiGenSchema).

        Returns { Parameters, BodyMode ('None'|'Flattened'|'Body'), BodyRequired, ContentTypes,
        Pageable, BinaryResponse, Findings }.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Operation,

        [Parameter()]
        [AllowEmptyString()]
        [string]$BaseNoun = '',

        [Parameter()]
        [AllowNull()]
        [object]$Schemas
    )

    $comparer = [System.StringComparer]::OrdinalIgnoreCase
    $commonParameters = @(
        'Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'InformationAction', 'ErrorVariable', 'WarningVariable',
        'InformationVariable', 'OutVariable', 'OutBuffer', 'PipelineVariable', 'WhatIf', 'Confirm', 'ProgressAction'
    )
    $commonAliases = @('vb', 'db', 'ea', 'wa', 'infa', 'ev', 'wv', 'iv', 'ov', 'ob', 'pv', 'wi', 'cf', 'proga')
    $wrapperParameters = @('All', 'Raw', 'OutFile', 'Body', 'ContentType')
    $automaticVariables = @(
        'Args', 'ConsoleFileName', 'Error', 'Event', 'EventArgs', 'EventSubscriber', 'ExecutionContext', 'False',
        'ForEach', 'Home', 'Host', 'Input', 'IsCoreCLR', 'IsLinux', 'IsMacOS', 'IsWindows', 'LastExitCode',
        'Matches', 'MyInvocation', 'NestedPromptLevel', 'Null', 'OFS', 'PID', 'Profile', 'PSBoundParameters',
        'PSCmdlet', 'PSCommandPath', 'PSCulture', 'PSDebugContext', 'PSEdition', 'PSHome', 'PSItem',
        'PSScriptRoot', 'PSSenderInfo', 'PSUICulture', 'PSVersionTable', 'PWD', 'Sender', 'ShellId',
        'StackTrace', 'Switch', 'This', 'True'
    )
    $reserved = New-Object -TypeName 'System.Collections.Generic.HashSet[string]' -ArgumentList $comparer
    foreach ($name in ($commonParameters + $wrapperParameters + $automaticVariables)) {
        [void]$reserved.Add($name)
    }
    $used = New-Object -TypeName 'System.Collections.Generic.HashSet[string]' -ArgumentList $comparer
    $findings = New-Object -TypeName System.Collections.ArrayList
    $parameters = New-Object -TypeName System.Collections.ArrayList
    $textInfo = [System.Globalization.CultureInfo]::InvariantCulture.TextInfo

    $newName = {
        param([string]$SpecName, [string]$In)
        $base = ConvertTo-OpenApiGenPascalCase -Value $SpecName
        if ($base -eq '') {
            $base = 'Parameter'
        }
        elseif ($base -match '^[0-9]') {
            $base = 'Parameter' + $base
        }
        # Names the wrapper uses for its own variables start with 'Tcs'
        $name = $base
        $reason = $null
        if ($reserved.Contains($name) -or $name -like 'Tcs*') {
            $reason = "'$name' is reserved (common parameter, wrapper parameter or automatic variable)"
        }
        elseif ($used.Contains($name)) {
            $reason = "another parameter is already named '$name'"
        }
        if ($null -ne $reason) {
            $name = $base + $textInfo.ToTitleCase($In)
            $number = 2
            while ($used.Contains($name) -or $reserved.Contains($name)) {
                $name = $base + $textInfo.ToTitleCase($In) + $number
                $number++
            }
            [void]$findings.Add((New-OpenApiGenFinding -Severity Warning -Code 'OA041' -Operation $Operation -Message "Parameter '$SpecName' ($In) of operation '$($Operation.OperationId)' is exposed as -$name because $reason."))
        }
        [void]$used.Add($name)
        return $name
    }
    $describe = {
        param($Item, $ItemSchema)
        $text = [string]$Item.Description
        if ([string]::IsNullOrWhiteSpace($text) -and $null -ne $ItemSchema) {
            $text = [string]$ItemSchema.Description
        }
        return $text
    }

    # 1. Spec parameters, grouped by location
    $specParameters = @($Operation.Parameters | Where-Object -FilterScript { $null -ne $_ })
    foreach ($location in @('path', 'query', 'header', 'cookie')) {
        foreach ($specParameter in @($specParameters | Where-Object -FilterScript { $_.In -eq $location })) {
            $required = ($location -eq 'path') -or ($specParameter.Required -eq $true)
            $type = Get-OpenApiGenParameterType -Schema $specParameter.Schema -In $location -Required:$required -Example $specParameter.Example -Schemas $Schemas
            [void]$parameters.Add([pscustomobject]@{
                    Name         = (& $newName ([string]$specParameter.Name) $location)
                    SpecName     = [string]$specParameter.Name
                    In           = $location
                    Kind         = 'Spec'
                    TypeName     = $type.TypeName
                    IsSwitch     = $type.IsSwitch
                    Mandatory    = $required
                    ParameterSet = $null
                    Aliases      = @()
                    Attributes   = $type.Attributes
                    Description  = (& $describe $specParameter $specParameter.Schema)
                    Deprecated   = ($specParameter.Deprecated -eq $true)
                    ExampleText  = $type.ExampleText
                    Pipeline     = $true
                })
        }
    }

    # 2. Request body
    $bodyMode = 'None'
    $bodyRequired = $false
    $contentTypes = @()
    $requestBody = $Operation.RequestBody
    if ($null -ne $requestBody) {
        $bodyRequired = ($requestBody.Required -eq $true)
        $media = @($requestBody.Content | Where-Object -FilterScript { $null -ne $_ })
        $contentTypes = @($media | ForEach-Object -Process { [string]$_.ContentType })
        $firstMedia = $null
        if ($media.Count -gt 0) {
            $firstMedia = $media[0]
        }
        $bodySchema = $null
        $kind = 'binary'
        if ($null -ne $firstMedia) {
            $bodySchema = Resolve-OpenApiGenSchema -Schema $firstMedia.Schema -Schemas $Schemas
            $kind = Get-OpenApiGenMediaKind -ContentType $firstMedia.ContentType -Schema $bodySchema
        }
        $properties = @()
        $isObject = $false
        if ($kind -eq 'json' -and $null -ne $bodySchema) {
            $alternatives = @(@($bodySchema.OneOf) + @($bodySchema.AnyOf) | Where-Object -FilterScript { $null -ne $_ })
            $properties = @(Get-OpenApiGenMapEntry -Map $bodySchema.Properties | Where-Object -FilterScript { $_.Value.ReadOnly -ne $true })
            $isObject = ($alternatives.Count -eq 0) -and ($bodySchema.Type -eq 'object' -or ([string]::IsNullOrEmpty([string]$bodySchema.Type) -and $properties.Count -gt 0))
        }
        if ($isObject -and $properties.Count -gt 0) {
            $bodyMode = 'Flattened'
            $requiredProperties = @($bodySchema.Required | Where-Object -FilterScript { $null -ne $_ } | ForEach-Object -Process { [string]$_ })
            foreach ($property in $properties) {
                $propertyRequired = $bodyRequired -and ($requiredProperties -ccontains $property.Key)
                $type = Get-OpenApiGenParameterType -Schema $property.Value -In 'body' -Required:$propertyRequired -Schemas $Schemas
                [void]$parameters.Add([pscustomobject]@{
                        Name         = (& $newName $property.Key 'body')
                        SpecName     = $property.Key
                        In           = 'body'
                        Kind         = 'BodyProperty'
                        TypeName     = $type.TypeName
                        IsSwitch     = $type.IsSwitch
                        Mandatory    = $propertyRequired
                        ParameterSet = 'Parameters'
                        Aliases      = @()
                        Attributes   = $type.Attributes
                        Description  = [string]$property.Value.Description
                        Deprecated   = ($property.Value.Deprecated -eq $true)
                        ExampleText  = $type.ExampleText
                        Pipeline     = $true
                    })
            }
        }
        else {
            $bodyMode = 'Body'
        }
        $bodyType = 'object'
        $bodyExample = "'example'"
        $objectSchemas = @(@($bodySchema) + @($bodySchema.OneOf) + @($bodySchema.AnyOf) | Where-Object -FilterScript {
                $null -ne $_ -and ($_.Type -eq 'object' -or @(Get-OpenApiGenMapEntry -Map (Resolve-OpenApiGenSchema -Schema $_ -Schemas $Schemas).Properties).Count -gt 0)
            })
        if ($kind -eq 'form' -or $kind -eq 'multipart' -or $bodyMode -eq 'Flattened' -or $objectSchemas.Count -gt 0) {
            $bodyExample = '@{}'
        }
        if ($kind -eq 'form' -or $kind -eq 'multipart') {
            $bodyType = 'hashtable'
        }
        elseif ($kind -eq 'binary') {
            $bodyExample = "(Get-Item -Path './file.bin')"
        }
        elseif ($null -ne $bodySchema -and $bodySchema.Type -eq 'array') {
            $bodyExample = '@()'
        }
        $bodyDescription = [string]$requestBody.Description
        if ($bodyMode -eq 'Flattened') {
            $bodyDescription = ('The whole request body (for example a hashtable or an object read from a file), instead of the individual body parameters. ' + $bodyDescription).Trim()
        }
        elseif ([string]::IsNullOrWhiteSpace($bodyDescription)) {
            $bodyDescription = 'The request body.'
        }
        if ($kind -eq 'multipart') {
            $bodyDescription += ' A hashtable of form fields; pass a file as a [System.IO.FileInfo] (Get-Item -Path ./file.txt).'
        }
        elseif ($kind -eq 'form') {
            $bodyDescription += ' A hashtable of form fields.'
        }
        elseif ($kind -eq 'binary') {
            $bodyDescription += ' A [byte[]], a [System.IO.Stream] or a [System.IO.FileInfo].'
        }
        [void]$used.Add('Body')
        $bodySet = $null
        if ($bodyMode -eq 'Flattened') {
            $bodySet = 'Body'
        }
        [void]$parameters.Add([pscustomobject]@{
                Name         = 'Body'
                SpecName     = $null
                In           = 'body'
                Kind         = 'Body'
                TypeName     = $bodyType
                IsSwitch     = $false
                Mandatory    = $bodyRequired
                ParameterSet = $bodySet
                Aliases      = @()
                Attributes   = @()
                Description  = $bodyDescription
                Deprecated   = $false
                ExampleText  = $bodyExample
                Pipeline     = $false
            })
        if ($contentTypes.Count -gt 1) {
            $literals = @($contentTypes | ForEach-Object -Process { ConvertTo-OpenApiGenLiteral -Value $_ })
            [void]$parameters.Add([pscustomobject]@{
                    Name         = 'ContentType'
                    SpecName     = $null
                    In           = $null
                    Kind         = 'ContentType'
                    TypeName     = 'string'
                    IsSwitch     = $false
                    Mandatory    = $false
                    ParameterSet = $null
                    Aliases      = @()
                    Attributes   = @('[ValidateSet(' + ($literals -join ', ') + ')]')
                    Description  = "The media type of the request body. Defaults to '$($contentTypes[0])'."
                    Deprecated   = $false
                    ExampleText  = $null
                    Pipeline     = $false
                })
        }
    }

    # 3. Wrapper parameters
    $pageable = ($null -ne $Operation.Paging)
    $binaryResponse = $false
    foreach ($response in @($Operation.Responses | Where-Object -FilterScript { $null -ne $_ -and ([string]$_.StatusCode) -match '^2' })) {
        foreach ($responseMedia in @($response.Content | Where-Object -FilterScript { $null -ne $_ })) {
            if ((Get-OpenApiGenMediaKind -ContentType $responseMedia.ContentType -Schema $responseMedia.Schema) -eq 'binary') {
                $binaryResponse = $true
            }
        }
    }
    $wrapper = @()
    if ($pageable) {
        $allHelp = 'Follows the next-page links and returns the items of every page.'
        if ([string](Get-OpenApiGenMapValue -Map $Operation.Paging -Key 'Kind') -eq 'token') {
            $allHelp = "Requests the following pages (the $(Get-OpenApiGenMapValue -Map $Operation.Paging -Key 'TokenParameter') query parameter set from each response) and returns the items of every page."
        }
        $wrapper += , @('All', 'switch', $allHelp)
    }
    if ($binaryResponse) {
        $wrapper += , @('OutFile', 'string', 'Saves the response content to this file and returns the file.')
    }
    $wrapper += , @('Raw', 'switch', 'Returns the raw response (StatusCode, Headers and Content) instead of the parsed content.')
    foreach ($entry in $wrapper) {
        [void]$parameters.Add([pscustomobject]@{
                Name         = $entry[0]
                SpecName     = $null
                In           = $null
                Kind         = $entry[0]
                TypeName     = $entry[1]
                IsSwitch     = ($entry[1] -eq 'switch')
                Mandatory    = $false
                ParameterSet = $null
                Aliases      = @()
                Attributes   = @()
                Description  = $entry[2]
                Deprecated   = $false
                ExampleText  = $null
                Pipeline     = $false
            })
    }

    # 4. Aliases: the spec name, and Id for the path parameter named after the noun
    $taken = New-Object -TypeName 'System.Collections.Generic.HashSet[string]' -ArgumentList $comparer
    foreach ($item in $parameters) {
        [void]$taken.Add($item.Name)
    }
    foreach ($name in ($commonParameters + $commonAliases)) {
        [void]$taken.Add($name)
    }
    $nounWords = @(Split-OpenApiGenWord -Value $BaseNoun)
    $idNames = @()
    if ($BaseNoun -ne '') {
        $idNames += $BaseNoun + 'Id'
    }
    if ($nounWords.Count -gt 0) {
        $idNames += (ConvertTo-OpenApiGenPascalCase -Word @($nounWords[$nounWords.Count - 1])) + 'Id'
    }
    $idGiven = $false
    foreach ($item in $parameters) {
        if ($item.Kind -ne 'Spec' -and $item.Kind -ne 'BodyProperty') {
            continue
        }
        $aliases = @()
        if ($item.SpecName -cne $item.Name -and $item.SpecName -match '^[A-Za-z][A-Za-z0-9_.-]*$' -and -not $taken.Contains($item.SpecName)) {
            $aliases += $item.SpecName
            [void]$taken.Add($item.SpecName)
        }
        if (-not $idGiven -and $item.In -eq 'path' -and ($idNames -contains $item.Name) -and -not $taken.Contains('Id')) {
            $aliases += 'Id'
            [void]$taken.Add('Id')
            $idGiven = $true
        }
        $item.Aliases = $aliases
    }

    return [pscustomobject]@{
        Parameters     = $parameters.ToArray()
        BodyMode       = $bodyMode
        BodyRequired   = $bodyRequired
        ContentTypes   = $contentTypes
        Pageable       = $pageable
        BinaryResponse = $binaryResponse
        Findings       = $findings.ToArray()
    }
}
