function ConvertTo-OpenApiDocumentModel {
    <#
    .SYNOPSIS
        Turns a raw document tree (any supported version) into the normalised document model. Never throws for document problems.
    .DESCRIPTION
        Detects the version (OA001 when unsupported: the model then has no operations), converts Swagger 2.0
        to the OpenAPI 3 shape, then normalises servers, security schemes, the default security, every
        component schema (first, in document order, so they are cached) and every operation. Missing
        operationIds are generated (OA010); duplicates (compared case-insensitively, as the generated module
        keys operations in a hashtable) get a '_2', '_3'... suffix (OA011). Missing paths give OA002 (Error;
        Warning for 3.1, where paths are optional).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Root,

        [AllowNull()]
        [uri]$BaseUri
    )

    $version = Get-OpenApiDocumentVersion -Root $Root
    $model = [pscustomobject]@{
        PSTypeName      = 'Tcs.OpenApi.Document'
        SourceVersion   = $version.SourceVersion
        Title           = $null
        Version         = $null
        Description     = $null
        Servers         = @()
        SecuritySchemes = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
        Security        = @()
        Schemas         = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
        Operations      = @()
        Findings        = @()
    }

    if (-not $version.Supported) {
        $context = Get-OpenApiNormalizationContext -Root $Root -SourceVersion $version.SourceVersion
        Add-OpenApiFinding -Context $context -Severity Error -Code 'OA001' -Pointer $version.Pointer -Message $version.Message
        $model.Findings = $context.Findings.ToArray()
        return $model
    }

    if ($version.Family -eq '2.0') {
        $Root = ConvertFrom-OpenApiSwagger2 -Root $Root -BaseUri $BaseUri
    }
    $context = Get-OpenApiNormalizationContext -Root $Root -SourceVersion $version.SourceVersion

    $info = $Root['info']
    if ($info -is [System.Collections.IDictionary]) {
        foreach ($pair in @(@('title', 'Title'), @('version', 'Version'), @('description', 'Description'))) {
            if ($null -ne $info[$pair[0]]) {
                $model.($pair[1]) = [string]$info[$pair[0]]
            }
        }
    }

    $model.Servers = Get-OpenApiServerList -Servers $Root['servers'] -BaseUri $BaseUri

    $components = $Root['components']
    if ($components -isnot [System.Collections.IDictionary]) {
        $components = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
    }
    if ($components['securitySchemes'] -is [System.Collections.IDictionary]) {
        foreach ($name in @($components['securitySchemes'].Keys)) {
            $pointer = Join-OpenApiJsonPointer -Pointer '/components/securitySchemes' -Segment $name
            $resolved = Resolve-OpenApiComponentReference -Context $context -Node $components['securitySchemes'][$name] -Pointer $pointer
            if ($null -ne $resolved -and $resolved.Node -is [System.Collections.IDictionary]) {
                $model.SecuritySchemes[$name] = ConvertTo-OpenApiSecurityScheme -Context $context -Name $name -Node $resolved.Node -Pointer $pointer
            }
        }
    }
    if ($Root.Contains('security')) {
        $model.Security = ConvertTo-OpenApiSecurityRequirement -Context $context -Requirement $Root['security'] -Pointer '/security'
    }

    if ($components['schemas'] -is [System.Collections.IDictionary]) {
        foreach ($name in @($components['schemas'].Keys)) {
            $pointer = Join-OpenApiJsonPointer -Pointer '/components/schemas' -Segment $name
            $model.Schemas[$name] = Resolve-OpenApiSchemaReference -Context $context -Reference ('#' + $pointer.Replace('%', '%25')) -Pointer $pointer
        }
    }

    $paths = $Root['paths']
    if ($paths -isnot [System.Collections.IDictionary]) {
        $severity = 'Error'
        if ($version.Family -eq '3.1') {
            $severity = 'Warning'
        }
        Add-OpenApiFinding -Context $context -Severity $severity -Code 'OA002' -Pointer '/paths' -Message "The document has no 'paths'; no operations can be generated."
        $model.Findings = $context.Findings.ToArray()
        return $model
    }

    # Pass 1: list operations and settle their operationIds
    $methods = @('get', 'put', 'post', 'delete', 'options', 'head', 'patch', 'trace')
    $entries = New-Object -TypeName System.Collections.Generic.List[object]
    foreach ($path in @($paths.Keys)) {
        $pathItemPointer = Join-OpenApiJsonPointer -Pointer '/paths' -Segment $path
        $resolvedItem = Resolve-OpenApiComponentReference -Context $context -Node $paths[$path] -Pointer $pathItemPointer
        if ($null -eq $resolvedItem -or $resolvedItem.Node -isnot [System.Collections.IDictionary]) {
            continue
        }
        foreach ($key in @($resolvedItem.Node.Keys)) {
            if ($methods -cnotcontains $key -or $resolvedItem.Node[$key] -isnot [System.Collections.IDictionary]) {
                continue
            }
            $rawId = $resolvedItem.Node[$key]['operationId']
            $entries.Add([pscustomobject]@{
                    Path            = $path
                    Method          = $key
                    Operation       = $resolvedItem.Node[$key]
                    PathItem        = $resolvedItem.Node
                    PathItemPointer = $resolvedItem.Pointer
                    Pointer         = Join-OpenApiJsonPointer -Pointer $resolvedItem.Pointer -Segment $key
                    SpecId          = $(if ($null -ne $rawId -and -not [string]::IsNullOrWhiteSpace([string]$rawId)) { [string]$rawId } else { $null })
                    OperationId     = $null
                })
        }
    }
    $used = New-Object -TypeName System.Collections.Generic.HashSet[string] -ArgumentList ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in $entries) {
        if ($null -eq $entry.SpecId) {
            continue
        }
        $id = $entry.SpecId
        $suffix = 2
        while (-not $used.Add($id)) {
            $id = '{0}_{1}' -f $entry.SpecId, $suffix
            $suffix++
        }
        if ($id -cne $entry.SpecId) {
            Add-OpenApiFinding -Context $context -Severity Warning -Code 'OA011' -Pointer (Join-OpenApiJsonPointer -Pointer $entry.Pointer -Segment 'operationId') -Operation $id -Message "Duplicate operationId '$($entry.SpecId)'; this operation uses '$id'."
        }
        $entry.OperationId = $id
    }
    foreach ($entry in $entries) {
        if ($null -ne $entry.SpecId) {
            continue
        }
        $generated = Get-OpenApiOperationId -Method $entry.Method -Path $entry.Path
        $id = $generated
        $suffix = 2
        while (-not $used.Add($id)) {
            $id = '{0}_{1}' -f $generated, $suffix
            $suffix++
        }
        Add-OpenApiFinding -Context $context -Severity Warning -Code 'OA010' -Pointer $entry.Pointer -Operation $id -Message "Operation $($entry.Method.ToUpperInvariant()) $($entry.Path) has no operationId; '$id' is used."
        $entry.OperationId = $id
    }

    # Pass 2: build the operations
    $operations = New-Object -TypeName System.Collections.Generic.List[object]
    foreach ($entry in $entries) {
        $operations.Add((ConvertTo-OpenApiOperation -Context $context -OperationId $entry.OperationId -Method $entry.Method -Path $entry.Path -Operation $entry.Operation -PathItem $entry.PathItem -PathItemPointer $entry.PathItemPointer))
    }
    $model.Operations = $operations.ToArray()
    $model.Findings = $context.Findings.ToArray()
    return $model
}
