function ConvertFrom-OpenApiSwagger2 {
    <#
    .SYNOPSIS
        Converts a raw Swagger 2.0 document tree to the raw OpenAPI 3.0 shape the normaliser reads.
    .DESCRIPTION
        - schemes/host/basePath -> servers (one per scheme, default https; without host the server is
          basePath, or the host of BaseUri when the document was downloaded).
        - definitions -> components.schemas ('#/definitions/...' refs are resolved against it).
        - securityDefinitions -> components.securitySchemes (ConvertFrom-OpenApiSwagger2SecurityScheme).
        - paths/operations via ConvertFrom-OpenApiSwagger2Operation.
        - info, tags, externalDocs, security and x- extensions (document, path item, operation) are kept.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Root,

        [AllowNull()]
        [uri]$BaseUri
    )

    $result = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
    $result['openapi'] = '3.0.3'
    foreach ($key in @($Root.Keys)) {
        if ($key -cin @('info', 'tags', 'externalDocs', 'security') -or $key.StartsWith('x-')) {
            $result[$key] = $Root[$key]
        }
    }

    # Servers
    $basePath = [string]$Root['basePath']
    if ([string]::IsNullOrEmpty($basePath)) {
        $basePath = '/'
    }
    if (-not $basePath.StartsWith('/')) {
        $basePath = '/' + $basePath
    }
    $hostName = [string]$Root['host']
    $schemes = @($Root['schemes'] | Where-Object { -not [string]::IsNullOrEmpty([string]$_) } | ForEach-Object { [string]$_ })
    if ([string]::IsNullOrEmpty($hostName) -and $null -ne $BaseUri -and $BaseUri.IsAbsoluteUri) {
        $hostName = $BaseUri.Authority
        if ($schemes.Count -eq 0) {
            $schemes = @($BaseUri.Scheme)
        }
    }
    $servers = New-Object -TypeName System.Collections.Generic.List[object]
    if ([string]::IsNullOrEmpty($hostName)) {
        $server = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
        $server['url'] = $basePath
        $servers.Add($server)
    }
    else {
        if ($schemes.Count -eq 0) {
            $schemes = @('https')
        }
        foreach ($scheme in $schemes) {
            $server = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
            $server['url'] = ('{0}://{1}{2}' -f $scheme, $hostName, $basePath).TrimEnd('/')
            $servers.Add($server)
        }
    }
    $result['servers'] = $servers.ToArray()

    # Components
    $components = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
    if ($Root['definitions'] -is [System.Collections.IDictionary]) {
        $components['schemas'] = $Root['definitions']
    }
    if ($Root['securityDefinitions'] -is [System.Collections.IDictionary]) {
        $securitySchemes = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
        foreach ($name in @($Root['securityDefinitions'].Keys)) {
            $definition = $Root['securityDefinitions'][$name]
            if ($definition -is [System.Collections.IDictionary]) {
                $securitySchemes[$name] = ConvertFrom-OpenApiSwagger2SecurityScheme -Node $definition
            }
        }
        $components['securitySchemes'] = $securitySchemes
    }
    $result['components'] = $components

    # Paths
    $globalConsumes = @($Root['consumes'] | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_ })
    $globalProduces = @($Root['produces'] | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_ })
    if ($Root['paths'] -is [System.Collections.IDictionary]) {
        $paths = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
        foreach ($path in @($Root['paths'].Keys)) {
            $item = $Root['paths'][$path]
            if ($item -isnot [System.Collections.IDictionary] -or $item.Contains('$ref')) {
                $paths[$path] = $item
                continue
            }
            $converted = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
            foreach ($key in @($item.Keys)) {
                if ($key -cin @('get', 'put', 'post', 'delete', 'options', 'head', 'patch') -and $item[$key] -is [System.Collections.IDictionary]) {
                    $converted[$key] = ConvertFrom-OpenApiSwagger2Operation -Root $Root -Operation $item[$key] -PathParameters $item['parameters'] -Consumes $globalConsumes -Produces $globalProduces
                }
                elseif ($key.StartsWith('x-')) {
                    $converted[$key] = $item[$key]
                }
            }
            $paths[$path] = $converted
        }
        $result['paths'] = $paths
    }
    return $result
}
