function ConvertTo-OpenApiParameter {
    <#
    .SYNOPSIS
        Normalises a resolved raw parameter into { Name, In, Required, Description, Deprecated, Schema, Style, Explode, AllowReserved, Example }.
    .DESCRIPTION
        Defaults per the specification: style 'simple' for path/header and 'form' for query/cookie;
        explode true for 'form' and false otherwise; path parameters are always required. A parameter
        with 'content' instead of 'schema' uses the schema of its first media type.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Node,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Pointer
    )

    $in = [string]$Node['in']
    $schema = $null
    if ($Node.Contains('schema')) {
        $schema = ConvertTo-OpenApiSchema -Context $Context -Node $Node['schema'] -Pointer (Join-OpenApiJsonPointer -Pointer $Pointer -Segment 'schema')
    }
    elseif ($Node['content'] -is [System.Collections.IDictionary] -and $Node['content'].Count -gt 0) {
        $contentType = @($Node['content'].Keys)[0]
        $media = $Node['content'][$contentType]
        if ($media -is [System.Collections.IDictionary]) {
            $schema = ConvertTo-OpenApiSchema -Context $Context -Node $media['schema'] -Pointer (Join-OpenApiJsonPointer -Pointer $Pointer -Segment 'content', $contentType, 'schema')
        }
    }

    $style = [string]$Node['style']
    if ([string]::IsNullOrEmpty($style)) {
        if ($in -eq 'query' -or $in -eq 'cookie') {
            $style = 'form'
        }
        else {
            $style = 'simple'
        }
    }
    if ($Node.Contains('explode') -and $null -ne $Node['explode']) {
        $explode = $Node['explode'] -eq $true
    }
    else {
        $explode = $style -eq 'form'
    }

    $example = $null
    if ($Node.Contains('example')) {
        $example = $Node['example']
    }
    elseif ($Node['examples'] -is [System.Collections.IDictionary] -and $Node['examples'].Count -gt 0) {
        $first = $Node['examples'][@($Node['examples'].Keys)[0]]
        if ($first -is [System.Collections.IDictionary]) {
            $example = $first['value']
        }
    }
    if ($null -eq $example -and $null -ne $schema) {
        $example = $schema.Example
    }

    $description = $null
    if ($null -ne $Node['description']) {
        $description = [string]$Node['description']
    }

    [pscustomobject]@{
        PSTypeName    = 'Tcs.OpenApi.Parameter'
        Name          = [string]$Node['name']
        In            = $in
        Required      = ($in -eq 'path') -or ($Node['required'] -eq $true)
        Description   = $description
        Deprecated    = $Node['deprecated'] -eq $true
        Schema        = $schema
        Style         = $style
        Explode       = $explode
        AllowReserved = $Node['allowReserved'] -eq $true
        Example       = $example
    }
}
