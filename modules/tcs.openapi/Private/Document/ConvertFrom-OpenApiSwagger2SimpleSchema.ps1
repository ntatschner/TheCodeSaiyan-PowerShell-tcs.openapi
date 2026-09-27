function ConvertFrom-OpenApiSwagger2SimpleSchema {
    <#
    .SYNOPSIS
        Builds an OpenAPI 3 schema from the inline type keywords of a Swagger 2.0 parameter, items or header object.
    .DESCRIPTION
        Copies type, format, items (recursively), enum, default and the validation keywords; 'type: file'
        becomes { type: string, format: binary }. x- extensions are kept.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Node
    )

    $schema = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
    if ([string]$Node['type'] -ceq 'file') {
        $schema['type'] = 'string'
        $schema['format'] = 'binary'
    }
    elseif ($Node.Contains('type')) {
        $schema['type'] = $Node['type']
    }
    $keywords = @('format', 'enum', 'default', 'maximum', 'exclusiveMaximum', 'minimum', 'exclusiveMinimum', 'maxLength',
        'minLength', 'pattern', 'maxItems', 'minItems', 'uniqueItems', 'multipleOf', 'example')
    foreach ($keyword in $keywords) {
        if ($Node.Contains($keyword) -and -not $schema.Contains($keyword)) {
            $schema[$keyword] = $Node[$keyword]
        }
    }
    if ($Node['items'] -is [System.Collections.IDictionary]) {
        if ($Node['items'].Contains('$ref')) {
            $schema['items'] = $Node['items']
        }
        else {
            $schema['items'] = ConvertFrom-OpenApiSwagger2SimpleSchema -Node $Node['items']
        }
    }
    foreach ($key in @($Node.Keys)) {
        if ($key.StartsWith('x-')) {
            $schema[$key] = $Node[$key]
        }
    }
    return $schema
}
