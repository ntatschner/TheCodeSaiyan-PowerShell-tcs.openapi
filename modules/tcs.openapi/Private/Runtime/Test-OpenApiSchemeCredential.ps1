function Test-OpenApiSchemeCredential {
    <#
    .SYNOPSIS
        Tests whether a context has the credentials a security scheme needs (api key, basic credential, bearer token or OAuth2 client credentials).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Scheme,

        [Parameter(Mandatory)]
        [pscustomobject]$Context
    )

    if ($null -eq $Scheme) {
        return $false
    }
    $type = [string](Get-OpenApiMember -InputObject $Scheme -Name 'Type')
    switch ($type) {
        'apiKey' {
            return ($null -ne $Context.ApiKey)
        }
        'http' {
            $httpScheme = ([string](Get-OpenApiMember -InputObject $Scheme -Name 'Scheme')).ToLowerInvariant()
            if ($httpScheme -eq 'basic') {
                return ($null -ne $Context.Credential)
            }
            if ($httpScheme -eq 'bearer') {
                return ($null -ne $Context.BearerToken)
            }
            return $false
        }
        'oauth2' {
            if ($null -ne $Context.BearerToken) {
                return $true
            }
            $tokenUri = Get-OpenApiTokenUri -Scheme $Scheme -Context $Context
            return (-not [string]::IsNullOrEmpty($Context.ClientId) -and $null -ne $Context.ClientSecret -and -not [string]::IsNullOrEmpty($tokenUri))
        }
        'openIdConnect' {
            return ($null -ne $Context.BearerToken)
        }
    }
    return $false
}
