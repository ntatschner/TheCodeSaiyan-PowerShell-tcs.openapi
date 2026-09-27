function ConvertTo-OpenApiGenMetadataEntry {
    <#
    .SYNOPSIS
        Builds the runtime view of an operation (DESIGN.md "Operation metadata") that the generated
        module stores in OpenApi/operations.json.

    .DESCRIPTION
        Security is the operation's own requirement list, or the document default when the operation
        has none (null stays null when neither is set); SecuritySchemes holds a copy of the schemes
        those requirements name. ResponseTypeName is '<Service>.<RefName>' of the first 2xx JSON
        response schema (or of its array items); for an operation whose Paging names an
        ItemsProperty it is the type of that property's items, because the engine outputs the items
        of each page, not the page. The result is an ordered dictionary so the JSON
        written from it keeps the documented property order.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Operation,

        [Parameter(Mandatory = $true)]
        [object]$Document,

        [Parameter(Mandatory = $true)]
        [string]$Service
    )

    $parameters = @(foreach ($parameter in @($Operation.Parameters | Where-Object -FilterScript { $null -ne $_ })) {
            $style = [string]$parameter.Style
            if ($style -eq '') {
                $style = 'simple'
                if ($parameter.In -eq 'query' -or $parameter.In -eq 'cookie') {
                    $style = 'form'
                }
            }
            $explode = $parameter.Explode
            if ($null -eq $explode) {
                $explode = ($style -eq 'form')
            }
            [ordered]@{
                Name          = [string]$parameter.Name
                In            = [string]$parameter.In
                Style         = $style
                Explode       = [bool]$explode
                AllowReserved = ($parameter.AllowReserved -eq $true)
            }
        })

    $requestContentTypes = @()
    if ($null -ne $Operation.RequestBody) {
        $requestContentTypes = @($Operation.RequestBody.Content | Where-Object -FilterScript { $null -ne $_ } | ForEach-Object -Process { [string]$_.ContentType })
    }

    $responseContentTypes = New-Object -TypeName System.Collections.ArrayList
    $binaryResponse = $false
    $responseTypeName = $null
    $successResponses = @($Operation.Responses | Where-Object -FilterScript { $null -ne $_ -and ([string]$_.StatusCode) -match '^2' })
    $sortedResponses = Get-OpenApiGenOrdinalSorted -InputObject $successResponses -Key { [string]$_.StatusCode }
    foreach ($response in @($Operation.Responses | Where-Object -FilterScript { $null -ne $_ })) {
        foreach ($media in @($response.Content | Where-Object -FilterScript { $null -ne $_ })) {
            if (-not $responseContentTypes.Contains([string]$media.ContentType)) {
                [void]$responseContentTypes.Add([string]$media.ContentType)
            }
        }
    }
    foreach ($response in $sortedResponses) {
        foreach ($media in @($response.Content | Where-Object -FilterScript { $null -ne $_ })) {
            $kind = Get-OpenApiGenMediaKind -ContentType $media.ContentType -Schema $media.Schema
            if ($kind -eq 'binary') {
                $binaryResponse = $true
            }
            if ($kind -eq 'json' -and $null -eq $responseTypeName -and $null -ne $media.Schema) {
                $refName = $media.Schema.RefName
                $itemsProperty = [string](Get-OpenApiGenMapValue -Map $Operation.Paging -Key 'ItemsProperty')
                $itemsSchema = $null
                if ($itemsProperty -ne '') {
                    $pageSchema = Resolve-OpenApiGenSchema -Schema $media.Schema -Schemas $Document.Schemas
                    $itemsSchema = Get-OpenApiGenMapValue -Map $pageSchema.Properties -Key $itemsProperty
                }
                if ($null -ne $itemsSchema) {
                    # The engine outputs the items of a page, so they carry the type name of the items
                    $refName = $null
                    if ($null -ne $itemsSchema.Items) {
                        $refName = $itemsSchema.Items.RefName
                    }
                }
                elseif ([string]::IsNullOrEmpty([string]$refName) -and $media.Schema.Type -eq 'array' -and $null -ne $media.Schema.Items) {
                    $refName = $media.Schema.Items.RefName
                }
                if (-not [string]::IsNullOrEmpty([string]$refName)) {
                    $responseTypeName = $Service + '.' + [string]$refName
                }
            }
        }
    }

    $security = $Operation.Security
    if ($null -eq $security) {
        $security = $Document.Security
    }
    $securityCopy = $null
    $schemes = [ordered]@{}
    if ($null -ne $security) {
        $securityCopy = @(foreach ($requirement in @($security)) {
                $copy = [ordered]@{}
                foreach ($entry in @(Get-OpenApiGenMapEntry -Map $requirement)) {
                    $copy[$entry.Key] = @($entry.Value | Where-Object -FilterScript { $null -ne $_ } | ForEach-Object -Process { [string]$_ })
                }
                $copy
            })
        $names = New-Object -TypeName System.Collections.ArrayList
        foreach ($requirement in $securityCopy) {
            foreach ($name in $requirement.Keys) {
                if (-not $names.Contains($name)) {
                    [void]$names.Add($name)
                }
            }
        }
        foreach ($name in (Get-OpenApiGenOrdinalSorted -InputObject $names.ToArray())) {
            $scheme = Get-OpenApiGenMapValue -Map $Document.SecuritySchemes -Key $name
            if ($null -ne $scheme) {
                $schemes[$name] = $scheme
            }
        }
    }

    $metadata = [ordered]@{
        OperationId          = [string]$Operation.OperationId
        Method               = ([string]$Operation.Method).ToUpperInvariant()
        Path                 = [string]$Operation.Path
        Service              = $Service
        Deprecated           = ($Operation.Deprecated -eq $true)
        Parameters           = $parameters
        RequestContentTypes  = $requestContentTypes
        ResponseContentTypes = $responseContentTypes.ToArray()
        BinaryResponse       = $binaryResponse
        Security             = $securityCopy
        SecuritySchemes      = $schemes
        Paging               = $Operation.Paging
        ResponseTypeName     = $responseTypeName
    }
    return $metadata
}
