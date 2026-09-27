function ConvertFrom-OpenApiSwagger2SecurityScheme {
    <#
    .SYNOPSIS
        Converts a Swagger 2.0 security definition to an OpenAPI 3 security scheme.
    .DESCRIPTION
        basic -> http/basic; apiKey unchanged; oauth2 flows: application -> clientCredentials,
        implicit -> implicit, password -> password, accessCode -> authorizationCode. x- extensions are kept.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Node
    )

    $scheme = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
    $type = [string]$Node['type']
    switch ($type) {
        'basic' {
            $scheme['type'] = 'http'
            $scheme['scheme'] = 'basic'
        }
        'apiKey' {
            $scheme['type'] = 'apiKey'
            $scheme['name'] = $Node['name']
            $scheme['in'] = $Node['in']
        }
        'oauth2' {
            $scheme['type'] = 'oauth2'
            $flowNames = @{ application = 'clientCredentials'; implicit = 'implicit'; password = 'password'; accessCode = 'authorizationCode' }
            $flow = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
            foreach ($key in @('authorizationUrl', 'tokenUrl')) {
                if ($Node.Contains($key)) {
                    $flow[$key] = $Node[$key]
                }
            }
            $scopes = $Node['scopes']
            if ($scopes -isnot [System.Collections.IDictionary]) {
                $scopes = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
            }
            $flow['scopes'] = $scopes
            $flows = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
            $flowName = [string]$Node['flow']
            if ($flowNames.ContainsKey($flowName)) {
                $flowName = $flowNames[$flowName]
            }
            $flows[$flowName] = $flow
            $scheme['flows'] = $flows
        }
        default {
            $scheme['type'] = $type
        }
    }
    foreach ($key in @($Node.Keys)) {
        if ($key -ceq 'description' -or $key.StartsWith('x-')) {
            $scheme[$key] = $Node[$key]
        }
    }
    return $scheme
}
