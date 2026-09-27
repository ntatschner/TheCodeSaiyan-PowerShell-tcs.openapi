function ConvertFrom-OpenApiSwagger2Parameter {
    <#
    .SYNOPSIS
        Converts a Swagger 2.0 non-body parameter (path/query/header) to an OpenAPI 3 parameter.
    .DESCRIPTION
        type/format/items/enum/default/validation keywords move into 'schema'. For arrays, collectionFormat
        maps to style/explode: csv -> form (simple for path/header) explode false, ssv -> spaceDelimited,
        pipes -> pipeDelimited, multi -> form explode true; tsv has no OpenAPI 3 equivalent and is treated as csv.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Node
    )

    $parameter = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
    foreach ($key in @('name', 'in', 'description', 'required', 'allowEmptyValue')) {
        if ($Node.Contains($key)) {
            $parameter[$key] = $Node[$key]
        }
    }
    foreach ($key in @($Node.Keys)) {
        if ($key.StartsWith('x-')) {
            $parameter[$key] = $Node[$key]
        }
    }
    $parameter['schema'] = ConvertFrom-OpenApiSwagger2SimpleSchema -Node $Node

    if ([string]$Node['type'] -ceq 'array') {
        $format = [string]$Node['collectionFormat']
        if ([string]::IsNullOrEmpty($format)) {
            $format = 'csv'
        }
        $in = [string]$Node['in']
        $simpleLocation = $in -eq 'path' -or $in -eq 'header'
        switch ($format) {
            'multi' {
                $parameter['style'] = 'form'
                $parameter['explode'] = $true
            }
            'ssv' {
                $parameter['style'] = 'spaceDelimited'
                $parameter['explode'] = $false
            }
            'pipes' {
                $parameter['style'] = 'pipeDelimited'
                $parameter['explode'] = $false
            }
            default {
                if ($simpleLocation) {
                    $parameter['style'] = 'simple'
                }
                else {
                    $parameter['style'] = 'form'
                }
                $parameter['explode'] = $false
            }
        }
    }
    return $parameter
}
