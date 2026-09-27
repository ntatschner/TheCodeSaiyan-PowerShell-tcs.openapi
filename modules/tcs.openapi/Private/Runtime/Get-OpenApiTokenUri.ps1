function Get-OpenApiTokenUri {
    <#
    .SYNOPSIS
        Returns the OAuth2 token endpoint: the context's TokenUri, else the scheme's clientCredentials flow TokenUrl.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Scheme,

        [Parameter(Mandatory)]
        [pscustomobject]$Context
    )

    if (-not [string]::IsNullOrEmpty($Context.TokenUri)) {
        return $Context.TokenUri
    }
    $flows = Get-OpenApiMember -InputObject $Scheme -Name 'Flows'
    $clientCredentials = Get-OpenApiMember -InputObject $flows -Name 'clientCredentials'
    $tokenUrl = Get-OpenApiMember -InputObject $clientCredentials -Name 'TokenUrl'
    if ([string]::IsNullOrEmpty($tokenUrl)) {
        $tokenUrl = Get-OpenApiMember -InputObject $clientCredentials -Name 'tokenUrl'
    }
    return [string]$tokenUrl
}
