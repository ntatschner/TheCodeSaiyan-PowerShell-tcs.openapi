function ConvertTo-OpenApiSchema {
    <#
    .SYNOPSIS
        Normalises a raw schema node into the OAS 3.0-vocabulary schema object of the document model.
    .DESCRIPTION
        - $ref is resolved (Resolve-OpenApiSchemaReference); 'description' and 'nullable: true' next to a
          $ref are applied to a copy of the referenced schema.
        - 3.1 type arrays: ['string','null'] -> Type 'string', Nullable; several non-null types -> Type
          $null and OA031. 3.0 'nullable: true' -> Nullable.
        - allOf members are merged into Properties/Required (and Type, Format, Enum, Items,
          AdditionalProperties when the schema has none); AllOf keeps the members.
        - Without a 'type', a schema with properties/additionalProperties is an 'object' and one with
          items is an 'array'.
        - Boolean schemas (3.1 true/false) become a blank schema. Anything that is not an object gives $null.
        - -Shallow reads only the keywords of the node itself (no items, properties, additionalProperties
          schema, allOf/oneOf/anyOf or $ref); it is used for the stub of a circular reference.
        - allOf members that are reference stubs are merged from their full schema.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Node,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Pointer,

        [switch]$Shallow
    )

    if ($null -eq $Node) {
        return $null
    }
    if ($Node -is [bool]) {
        return Get-OpenApiBlankSchema
    }
    if ($Node -isnot [System.Collections.IDictionary]) {
        return $null
    }

    if ($Node.Contains('$ref')) {
        if ($Shallow) {
            return Get-OpenApiBlankSchema
        }
        $referenced = Resolve-OpenApiSchemaReference -Context $Context -Reference ([string]$Node['$ref']) -Pointer $Pointer
        $hasDescription = $Node.Contains('description') -and $null -ne $Node['description']
        $isNullable = $Node['nullable'] -eq $true
        if (-not $referenced.Recursive -and ($hasDescription -or $isNullable)) {
            $referenced = $referenced.PSObject.Copy()
            if ($hasDescription) {
                $referenced.Description = [string]$Node['description']
            }
            if ($isNullable) {
                $referenced.Nullable = $true
            }
        }
        return $referenced
    }

    $schema = Get-OpenApiBlankSchema
    $hasType = $Node.Contains('type')
    if ($hasType) {
        $rawType = $Node['type']
        if ($rawType -is [System.Collections.IList]) {
            $nonNull = [System.Collections.Generic.List[string]]::new()
            foreach ($item in $rawType) {
                if ([string]$item -ceq 'null') {
                    $schema.Nullable = $true
                }
                elseif (-not $nonNull.Contains([string]$item)) {
                    $nonNull.Add([string]$item)
                }
            }
            if ($nonNull.Count -eq 1) {
                $schema.Type = $nonNull[0]
            }
            elseif ($nonNull.Count -gt 1) {
                Add-OpenApiFinding -Context $Context -Severity Warning -Code 'OA031' -Pointer (Join-OpenApiJsonPointer -Pointer $Pointer -Segment 'type') -Message "Schema allows several types ($($nonNull -join ', ')); it is treated as untyped."
            }
        }
        elseif ([string]$rawType -ceq 'null') {
            $schema.Nullable = $true
        }
        elseif ($null -ne $rawType) {
            $schema.Type = [string]$rawType
        }
    }
    if ($Node['nullable'] -eq $true) {
        $schema.Nullable = $true
    }

    foreach ($pair in @(
            @('format', 'Format'), @('description', 'Description'), @('title', 'Title'), @('pattern', 'Pattern')
        )) {
        if ($null -ne $Node[$pair[0]]) {
            $schema.($pair[1]) = [string]$Node[$pair[0]]
        }
    }
    foreach ($pair in @(
            @('default', 'Default'), @('const', 'Const'), @('minimum', 'Minimum'), @('maximum', 'Maximum'),
            @('exclusiveMinimum', 'ExclusiveMinimum'), @('exclusiveMaximum', 'ExclusiveMaximum'),
            @('minLength', 'MinLength'), @('maxLength', 'MaxLength'), @('minItems', 'MinItems'), @('maxItems', 'MaxItems'),
            @('example', 'Example')
        )) {
        if ($Node.Contains($pair[0])) {
            $schema.($pair[1]) = $Node[$pair[0]]
        }
    }
    if ($null -eq $schema.Example -and $Node['examples'] -is [System.Collections.IList] -and $Node['examples'].Count -gt 0) {
        $schema.Example = $Node['examples'][0]
    }
    if ($Node.Contains('enum') -and $Node['enum'] -is [System.Collections.IList]) {
        $schema.Enum = [object[]]$Node['enum']
    }
    $schema.ReadOnly = $Node['readOnly'] -eq $true
    $schema.WriteOnly = $Node['writeOnly'] -eq $true
    $schema.Deprecated = $Node['deprecated'] -eq $true

    if (-not $Shallow -and $Node['discriminator'] -is [System.Collections.IDictionary]) {
        $schema.Discriminator = [pscustomobject]@{
            PropertyName = [string]$Node['discriminator']['propertyName']
            Mapping      = $Node['discriminator']['mapping']
        }
    }

    if (-not $Shallow -and $Node.Contains('items')) {
        $items = $Node['items']
        $itemsPointer = $Pointer + '/items'
        if ($items -is [System.Collections.IList]) {
            # Draft-4 style tuple: use the first item schema
            if ($items.Count -gt 0) {
                $items = $items[0]
                $itemsPointer += '/0'
            }
            else {
                $items = $null
            }
        }
        $schema.Items = ConvertTo-OpenApiSchema -Context $Context -Node $items -Pointer $itemsPointer
    }

    $properties = $null
    if (-not $Shallow -and $Node['properties'] -is [System.Collections.IDictionary]) {
        $properties = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
        # Pointers are built inline here (the hot path); property names are escaped as JSON pointer segments
        $propertiesPointer = $Pointer + '/properties/'
        foreach ($name in @($Node['properties'].Keys)) {
            $properties[$name] = ConvertTo-OpenApiSchema -Context $Context -Node $Node['properties'][$name] -Pointer ($propertiesPointer + $name.Replace('~', '~0').Replace('/', '~1'))
        }
    }
    $required = [System.Collections.Generic.List[string]]::new()
    if ($Node['required'] -is [System.Collections.IList]) {
        foreach ($name in $Node['required']) {
            if (-not $required.Contains([string]$name)) {
                $required.Add([string]$name)
            }
        }
    }

    if ($Node.Contains('additionalProperties')) {
        $additional = $Node['additionalProperties']
        if ($additional -is [bool]) {
            $schema.AdditionalProperties = $additional
        }
        elseif (-not $Shallow) {
            $schema.AdditionalProperties = ConvertTo-OpenApiSchema -Context $Context -Node $additional -Pointer ($Pointer + '/additionalProperties')
        }
    }

    foreach ($pair in @(@('allOf', 'AllOf'), @('oneOf', 'OneOf'), @('anyOf', 'AnyOf'))) {
        if (-not $Shallow -and $Node[$pair[0]] -is [System.Collections.IList]) {
            $members = [System.Collections.Generic.List[object]]::new()
            $index = 0
            foreach ($member in $Node[$pair[0]]) {
                $converted = ConvertTo-OpenApiSchema -Context $Context -Node $member -Pointer ('{0}/{1}/{2}' -f $Pointer, $pair[0], $index)
                if ($null -ne $converted) {
                    $members.Add($converted)
                }
                $index++
            }
            $schema.($pair[1]) = $members.ToArray()
        }
    }

    if ($null -ne $schema.AllOf) {
        $merged = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
        $mergedRequired = [System.Collections.Generic.List[string]]::new()
        foreach ($reference in $schema.AllOf) {
            # A reference stub has no structure of its own: merge its full schema
            $member = $reference
            if ($null -ne $reference.RefName) {
                $fullKey = Join-OpenApiJsonPointer -Pointer '/components/schemas' -Segment $reference.RefName
                if ($Context.SchemaCache.ContainsKey($fullKey)) {
                    $member = $Context.SchemaCache[$fullKey]
                }
            }
            if ($null -ne $member.Properties) {
                foreach ($name in @($member.Properties.Keys)) {
                    $merged[$name] = $member.Properties[$name]
                }
            }
            foreach ($name in @($member.Required)) {
                if (-not $mergedRequired.Contains($name)) {
                    $mergedRequired.Add($name)
                }
            }
            if (-not $hasType -and $null -eq $schema.Type -and $null -ne $member.Type) {
                $schema.Type = $member.Type
            }
            foreach ($field in 'Format', 'Enum', 'Items', 'AdditionalProperties') {
                if ($null -eq $schema.$field -and $null -ne $member.$field) {
                    $schema.$field = $member.$field
                }
            }
            if ($member.Nullable -and $schema.AllOf.Count -eq 1) {
                $schema.Nullable = $true
            }
        }
        if ($null -ne $properties) {
            foreach ($name in @($properties.Keys)) {
                $merged[$name] = $properties[$name]
            }
        }
        foreach ($name in $required) {
            if (-not $mergedRequired.Contains($name)) {
                $mergedRequired.Add($name)
            }
        }
        if ($merged.Count -gt 0 -or $null -ne $properties) {
            $properties = $merged
        }
        $required = $mergedRequired
    }

    $schema.Properties = $properties
    $schema.Required = $required.ToArray()

    if (-not $hasType -and $null -eq $schema.Type) {
        if ($null -ne $schema.Properties -or $null -ne $schema.AdditionalProperties -or ($Shallow -and ($Node.Contains('properties') -or $Node.Contains('additionalProperties')))) {
            $schema.Type = 'object'
        }
        elseif ($null -ne $schema.Items -or ($Shallow -and $Node.Contains('items'))) {
            $schema.Type = 'array'
        }
    }
    return $schema
}
