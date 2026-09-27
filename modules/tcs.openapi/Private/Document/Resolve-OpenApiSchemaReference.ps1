function Resolve-OpenApiSchemaReference {
    <#
    .SYNOPSIS
        Resolves a schema $ref to a normalised schema, with caching and circular-reference detection.
    .DESCRIPTION
        - External refs (not starting with '#'): OA020 Error, the current operation is marked as using one,
          and a blank schema is returned.
        - Unresolvable local refs: OA021 Error and a blank schema.
        - A ref to a schema that is being expanded (a cycle): OA022 Information and a stub
          { RefName, Recursive = $true } that is not expanded again.
        - Otherwise the target is normalised once and cached by its JSON pointer; later refs return the
          same object. RefName is set for '#/components/schemas/<name>' (and '#/definitions/<name>').
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Reference,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Pointer
    )

    if (-not $Reference.StartsWith('#')) {
        $Context.ExternalRefHits++
        Add-OpenApiFinding -Context $Context -Severity Error -Code 'OA020' -Pointer $Pointer -Message "External `$ref '$Reference' is not supported; the operations that use it are flagged Unsupported."
        return Get-OpenApiBlankSchema
    }

    $target = Resolve-OpenApiPointer -Root $Context.Root -Reference $Reference
    if (-not $target.Found) {
        Add-OpenApiFinding -Context $Context -Severity Error -Code 'OA021' -Pointer $Pointer -Message "`$ref '$Reference' could not be resolved."
        return Get-OpenApiBlankSchema
    }

    $key = $target.Pointer
    $refName = $null
    if ($key -match '^/components/schemas/([^/]+)$') {
        $refName = $Matches[1].Replace('~1', '/').Replace('~0', '~')
    }

    if ($Context.SchemaCache.ContainsKey($key)) {
        if ($Context.TaintedSchemas.Contains($key)) {
            $Context.ExternalRefHits++
        }
        return $Context.SchemaCache[$key]
    }

    if ($Context.SchemaStack.Contains($key)) {
        $name = $refName
        if ($null -eq $name) {
            $name = $key
        }
        Add-OpenApiFinding -Context $Context -Severity Information -Code 'OA022' -Pointer $key -Operation $null -Message "Schema '$name' is circular; the recursive reference is marked Recursive and not expanded again."
        $stub = Get-OpenApiBlankSchema
        $stub.RefName = $refName
        $stub.Recursive = $true
        return $stub
    }

    [void]$Context.SchemaStack.Add($key)
    $hitsBefore = $Context.ExternalRefHits
    try {
        $schema = ConvertTo-OpenApiSchema -Context $Context -Node $target.Value -Pointer $key
    }
    finally {
        [void]$Context.SchemaStack.Remove($key)
    }
    if ($null -eq $schema) {
        $schema = Get-OpenApiBlankSchema
    }
    if ($Context.ExternalRefHits -gt $hitsBefore) {
        [void]$Context.TaintedSchemas.Add($key)
    }
    if ($null -ne $refName) {
        if ($target.Value -is [System.Collections.IDictionary] -and $target.Value.Contains('$ref')) {
            # An alias of another schema: do not rename the shared object of the target
            $schema = $schema.PSObject.Copy()
        }
        $schema.RefName = $refName
    }
    $Context.SchemaCache[$key] = $schema
    return $schema
}
