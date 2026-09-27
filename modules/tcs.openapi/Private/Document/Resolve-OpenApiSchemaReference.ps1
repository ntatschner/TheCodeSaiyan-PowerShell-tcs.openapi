function Resolve-OpenApiSchemaReference {
    <#
    .SYNOPSIS
        Resolves a schema $ref to a normalised schema, with caching, reference stubs and circular-reference detection.
    .DESCRIPTION
        - External refs (not starting with '#'): OA020 Error, the current operation is marked as using one,
          and a blank schema is returned.
        - Unresolvable local refs: OA021 Error and a blank schema.
        - Otherwise the target is normalised once and cached by its JSON pointer. RefName is set for
          '#/components/schemas/<name>' (and '#/definitions/<name>'); a schema that is only a $ref to
          another one (an alias) is a copy of the full target under its own name.
        - A ref to a named schema made while another schema is being normalised (a nested ref) returns
          the reference stub of the target (ConvertTo-OpenApiSchemaStub) rather than the full schema, so
          the model stays linear in size; the full schema is Document.Schemas[RefName]. Refs made from an
          operation (parameters, bodies, responses, headers), the Schemas map, or with -Full get the full,
          shared schema object.
        - A nested ref to a schema that is still being normalised is a cycle: OA022 Information and a
          stub with Recursive = $true (built from the target's own keywords only).
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
        [string]$Pointer,

        [switch]$Full
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
    $asStub = (-not $Full) -and $null -ne $refName -and $Context.SchemaStack.Count -gt 0

    if ($Context.SchemaCache.ContainsKey($key)) {
        if ($Context.TaintedSchemas.Contains($key)) {
            $Context.ExternalRefHits++
        }
        $schema = $Context.SchemaCache[$key]
    }
    elseif ($Context.SchemaStack.Contains($key)) {
        $name = $refName
        if ($null -eq $name) {
            $name = $key
        }
        Add-OpenApiFinding -Context $Context -Severity Information -Code 'OA022' -Pointer $key -Operation $null -Message "Schema '$name' is circular; the recursive reference is marked Recursive and not expanded again."
        $stub = ConvertTo-OpenApiSchema -Context $Context -Node $target.Value -Pointer $key -Shallow
        if ($null -eq $stub) {
            $stub = Get-OpenApiBlankSchema
        }
        $stub.RefName = $refName
        $stub.Recursive = $true
        return $stub
    }
    else {
        [void]$Context.SchemaStack.Add($key)
        $hitsBefore = $Context.ExternalRefHits
        $raw = $target.Value
        try {
            if ($raw -is [System.Collections.IDictionary] -and $raw.Contains('$ref')) {
                # An alias of another schema: a copy of the full target, so the target keeps its own name
                $schema = Resolve-OpenApiSchemaReference -Context $Context -Reference ([string]$raw['$ref']) -Pointer $key -Full
                $schema = $schema.PSObject.Copy()
                if ($null -ne $raw['description']) {
                    $schema.Description = [string]$raw['description']
                }
                if ($raw['nullable'] -eq $true) {
                    $schema.Nullable = $true
                }
            }
            else {
                $schema = ConvertTo-OpenApiSchema -Context $Context -Node $raw -Pointer $key
            }
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
            $schema.RefName = $refName
        }
        $Context.SchemaCache[$key] = $schema
    }

    if ($asStub) {
        if (-not $Context.StubCache.ContainsKey($key)) {
            $Context.StubCache[$key] = ConvertTo-OpenApiSchemaStub -Schema $schema
        }
        return $Context.StubCache[$key]
    }
    return $schema
}
