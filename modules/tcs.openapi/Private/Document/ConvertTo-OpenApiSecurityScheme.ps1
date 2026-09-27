function ConvertTo-OpenApiSecurityScheme {
    <#
    .SYNOPSIS
        Normalises a resolved raw security scheme into the SecurityScheme object, with OA030 for unsupported kinds.
    .DESCRIPTION
        Returns { Name, Type, In, ParameterName, Scheme, BearerFormat, Flows, OpenIdConnectUrl, Description }.
        Flows maps flow names to { TokenUrl, AuthorizationUrl, RefreshUrl, Scopes }. OA030 (Warning) is
        written for openIdConnect, mutualTLS, unknown types, http schemes other than basic/bearer and
        oauth2 schemes without a clientCredentials flow (the runtime only fetches client-credentials tokens).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Node,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Pointer
    )

    $type = [string]$Node['type']
    $scheme = $null
    if ($null -ne $Node['scheme']) {
        $scheme = ([string]$Node['scheme']).ToLowerInvariant()
    }
    $flows = $null
    if ($Node['flows'] -is [System.Collections.IDictionary]) {
        $flows = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
        foreach ($flowName in @($Node['flows'].Keys)) {
            $flow = $Node['flows'][$flowName]
            if ($flow -isnot [System.Collections.IDictionary]) {
                continue
            }
            $scopes = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
            if ($flow['scopes'] -is [System.Collections.IDictionary]) {
                foreach ($scope in @($flow['scopes'].Keys)) {
                    $scopes[$scope] = $flow['scopes'][$scope]
                }
            }
            $flows[$flowName] = [pscustomobject]@{
                TokenUrl         = $flow['tokenUrl']
                AuthorizationUrl = $flow['authorizationUrl']
                RefreshUrl       = $flow['refreshUrl']
                Scopes           = $scopes
            }
        }
    }

    $reason = $null
    switch ($type) {
        'apiKey' {
        }
        'http' {
            if ($scheme -ne 'basic' -and $scheme -ne 'bearer') {
                $reason = "http scheme '$scheme' is not supported (only basic and bearer)"
            }
        }
        'oauth2' {
            if ($null -eq $flows -or -not $flows.Contains('clientCredentials')) {
                $reason = 'only the oauth2 clientCredentials flow is supported'
            }
        }
        'openIdConnect' {
            $reason = 'openIdConnect is not supported'
        }
        default {
            $reason = "security scheme type '$type' is not supported"
        }
    }
    if ($null -ne $reason) {
        Add-OpenApiFinding -Context $Context -Severity Warning -Code 'OA030' -Pointer $Pointer -Operation $null -Message "Security scheme '$Name': $reason; supply credentials with -Header or call Invoke-OpenApiRequest directly."
    }

    [pscustomobject]@{
        PSTypeName       = 'Tcs.OpenApi.SecurityScheme'
        Name             = $Name
        Type             = $type
        In               = $Node['in']
        ParameterName    = $Node['name']
        Scheme           = $scheme
        BearerFormat     = $Node['bearerFormat']
        Flows            = $flows
        OpenIdConnectUrl = $Node['openIdConnectUrl']
        Description      = $Node['description']
    }
}
