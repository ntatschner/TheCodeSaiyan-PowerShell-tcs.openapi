function ConvertFrom-OpenApiSwagger2Response {
    <#
    .SYNOPSIS
        Converts a resolved Swagger 2.0 response to an OpenAPI 3 response (schema -> content for each produces type).
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Node,

        [Parameter(Mandatory)]
        [string[]]$Produces
    )

    $response = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
    $response['description'] = $(if ($null -ne $Node['description']) { $Node['description'] } else { '' })
    if ($Node['headers'] -is [System.Collections.IDictionary]) {
        $headers = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
        foreach ($name in @($Node['headers'].Keys)) {
            $raw = $Node['headers'][$name]
            if ($raw -isnot [System.Collections.IDictionary]) {
                continue
            }
            $header = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
            if ($raw.Contains('description')) {
                $header['description'] = $raw['description']
            }
            $header['schema'] = ConvertFrom-OpenApiSwagger2SimpleSchema -Node $raw
            $headers[$name] = $header
        }
        $response['headers'] = $headers
    }
    if ($Node['schema'] -is [System.Collections.IDictionary]) {
        $schema = $Node['schema']
        if ([string]$schema['type'] -ceq 'file') {
            $schema = ConvertFrom-OpenApiSwagger2SimpleSchema -Node $schema
        }
        $content = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
        foreach ($contentType in $Produces) {
            $media = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
            $media['schema'] = $schema
            $content[$contentType] = $media
        }
        $response['content'] = $content
    }
    foreach ($key in @($Node.Keys)) {
        if ($key.StartsWith('x-')) {
            $response[$key] = $Node[$key]
        }
    }
    return $response
}
