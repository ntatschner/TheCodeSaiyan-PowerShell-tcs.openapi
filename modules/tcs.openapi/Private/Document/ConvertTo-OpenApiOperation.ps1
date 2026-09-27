function ConvertTo-OpenApiOperation {
    <#
    .SYNOPSIS
        Builds the Operation object of the document model from a raw operation and its path item.
    .DESCRIPTION
        Path-level parameters are merged in; an operation-level parameter replaces a path-level one with
        the same (Name, In) (header names compared case-insensitively). Security is $null when the
        operation does not declare it (use the document default), an empty array for 'security: []'.
        Any external $ref met while building the operation (directly or through a cached schema) sets
        Unsupported. Deprecated operations give OA060 (Information).
        A final catch-all path segment ('*name' as in router-style paths, or '{name*}') whose name is a path
        parameter becomes '{name}' in Path and that parameter gets CatchAll = $true: its value is a path of
        its own and keeps its '/' at call time. A path parameter that is not in the path template gives
        OA023 (Warning: it is ignored); a template placeholder without a path parameter gives OA024 (Error:
        the command cannot fill it). Names are compared case-sensitively.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [string]$OperationId,

        [Parameter(Mandatory)]
        [string]$Method,

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Operation,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$PathItem,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$PathItemPointer
    )

    $Context.CurrentOperation = $OperationId
    $hitsBefore = $Context.ExternalRefHits
    $pointer = Join-OpenApiJsonPointer -Pointer $PathItemPointer -Segment $Method.ToLowerInvariant()

    $parameters = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
    $parameterPointers = @{}
    foreach ($source in @(@($PathItem['parameters'], $PathItemPointer), @($Operation['parameters'], $pointer))) {
        if ($source[0] -isnot [System.Collections.IList]) {
            continue
        }
        $index = 0
        foreach ($rawParameter in $source[0]) {
            $parameterPointer = Join-OpenApiJsonPointer -Pointer $source[1] -Segment 'parameters', ([string]$index)
            $index++
            $resolved = Resolve-OpenApiComponentReference -Context $Context -Node $rawParameter -Pointer $parameterPointer
            if ($null -eq $resolved -or $resolved.Node -isnot [System.Collections.IDictionary]) {
                continue
            }
            $parameter = ConvertTo-OpenApiParameter -Context $Context -Node $resolved.Node -Pointer $resolved.Pointer
            $name = $parameter.Name
            if ($parameter.In -eq 'header') {
                $name = $name.ToLowerInvariant()
            }
            $parameters['{0}|{1}' -f $parameter.In, $name] = $parameter
            $parameterPointers['{0}|{1}' -f $parameter.In, $name] = $resolved.Pointer
        }
    }

    $requestBody = $null
    if ($Operation.Contains('requestBody')) {
        $resolvedBody = Resolve-OpenApiComponentReference -Context $Context -Node $Operation['requestBody'] -Pointer (Join-OpenApiJsonPointer -Pointer $pointer -Segment 'requestBody')
        if ($null -ne $resolvedBody -and $resolvedBody.Node -is [System.Collections.IDictionary]) {
            $requestBody = ConvertTo-OpenApiRequestBody -Context $Context -Node $resolvedBody.Node -Pointer $resolvedBody.Pointer
        }
    }

    $responses = ConvertTo-OpenApiResponseList -Context $Context -Responses $Operation['responses'] -Pointer (Join-OpenApiJsonPointer -Pointer $pointer -Segment 'responses')

    $security = $null
    if ($Operation.Contains('security')) {
        $security = ConvertTo-OpenApiSecurityRequirement -Context $Context -Requirement $Operation['security'] -Pointer (Join-OpenApiJsonPointer -Pointer $pointer -Segment 'security')
    }

    $tags = [System.Collections.Generic.List[string]]::new()
    if ($Operation['tags'] -is [System.Collections.IList]) {
        foreach ($tag in $Operation['tags']) {
            if ($null -ne $tag) {
                $tags.Add([string]$tag)
            }
        }
    }

    $extensions = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
    foreach ($key in @($Operation.Keys)) {
        if ($key.StartsWith('x-')) {
            $extensions[$key] = $Operation[$key]
        }
    }

    $externalDocsUrl = $null
    if ($Operation['externalDocs'] -is [System.Collections.IDictionary] -and $null -ne $Operation['externalDocs']['url']) {
        $externalDocsUrl = [string]$Operation['externalDocs']['url']
    }

    $deprecated = $Operation['deprecated'] -eq $true
    if ($deprecated) {
        Add-OpenApiFinding -Context $Context -Severity Information -Code 'OA060' -Pointer (Join-OpenApiJsonPointer -Pointer $pointer -Segment 'deprecated') -Message "Operation '$OperationId' is deprecated."
    }

    $unsupported = $Context.ExternalRefHits -gt $hitsBefore
    if ($unsupported) {
        $reported = @($Context.Findings | Where-Object { $_.Code -eq 'OA020' -and $_.Operation -eq $OperationId })
        if ($reported.Count -eq 0) {
            Add-OpenApiFinding -Context $Context -Severity Error -Code 'OA020' -Pointer $pointer -Message "Operation '$OperationId' uses a schema that contains an external `$ref; it is flagged Unsupported."
        }
    }

    # Path template: catch-all segment, parameters missing from the template and placeholders without a parameter
    $pathParameters = @($parameters.Keys | Where-Object -FilterScript { $_.StartsWith('path|') })
    $catchAll = [regex]::Match($Path, '/(?:\*([A-Za-z0-9_.~-]+)|\{([^{}*/]+)\*\})$')
    if ($catchAll.Success) {
        $catchAllName = $catchAll.Groups[1].Value
        if ($catchAllName -eq '') {
            $catchAllName = $catchAll.Groups[2].Value
        }
        $key = 'path|' + $catchAllName
        if ($pathParameters -ccontains $key) {
            $Path = $Path.Substring(0, $catchAll.Index) + '/{' + $catchAllName + '}'
            $parameters[$key].CatchAll = $true
        }
    }
    $placeholders = @([regex]::Matches($Path, '\{([^{}]+)\}') | ForEach-Object -Process { $_.Groups[1].Value })
    foreach ($key in $pathParameters) {
        $name = $key.Substring(5)
        if ($placeholders -cnotcontains $name) {
            Add-OpenApiFinding -Context $Context -Severity Warning -Code 'OA023' -Pointer $parameterPointers[$key] -Message "Path parameter '$name' is not in the path template '$Path'; it is ignored."
        }
    }
    $reportedPlaceholders = New-Object -TypeName 'System.Collections.Generic.HashSet[string]' -ArgumentList ([System.StringComparer]::Ordinal)
    foreach ($name in $placeholders) {
        if ($pathParameters -cnotcontains ('path|' + $name) -and $reportedPlaceholders.Add($name)) {
            Add-OpenApiFinding -Context $Context -Severity Error -Code 'OA024' -Pointer $PathItemPointer -Message "The path template '$Path' has the placeholder '{$name}' but no path parameter '$name'; the command cannot fill it."
        }
    }

    $summary = $null
    if ($null -ne $Operation['summary']) {
        $summary = [string]$Operation['summary']
    }
    $description = $null
    if ($null -ne $Operation['description']) {
        $description = [string]$Operation['description']
    }

    $result = [pscustomobject]@{
        PSTypeName      = 'Tcs.OpenApi.Operation'
        OperationId     = $OperationId
        Method          = $Method.ToUpperInvariant()
        Path            = $Path
        Tags            = $tags.ToArray()
        Summary         = $summary
        Description     = $description
        Deprecated      = $deprecated
        ExternalDocsUrl = $externalDocsUrl
        Parameters      = @($parameters.Values)
        RequestBody     = $requestBody
        Responses       = $responses
        Security        = $security
        Paging          = Get-OpenApiPaging -Operation $Operation -Responses $responses -Parameters @($parameters.Values)
        Extensions      = $extensions
        Unsupported     = $unsupported
    }
    $Context.CurrentOperation = $null
    return $result
}
