function Set-ReservedNamesContext {
    <#
    .SYNOPSIS
        Sets the connection (base URI and credentials) used by the Reserved.Names commands.

    .DESCRIPTION
        Calls Set-OpenApiContext from tcs.openapi for the service 'Reserved.Names' with the parameters you
        pass. Pass only the credentials the API needs; the request engine picks the ones each operation
        asks for.

    .PARAMETER BaseUri
        The base URI of the API. The document does not name an absolute server URL, so this is required.

    .PARAMETER ApiKey
        The API key, for operations secured with an apiKey scheme.

    .PARAMETER Credential
        The user name and password, for HTTP basic authentication.

    .PARAMETER BearerToken
        The token, for HTTP bearer authentication.

    .PARAMETER ClientId
        The client id, for the OAuth2 client credentials flow.

    .PARAMETER ClientSecret
        The client secret, for the OAuth2 client credentials flow.

    .PARAMETER TokenUri
        The token endpoint, for the OAuth2 client credentials flow.

    .PARAMETER Scope
        The scopes to request, for the OAuth2 client credentials flow.

    .PARAMETER Header
        Headers to send with every request.

    .PARAMETER TimeoutSec
        The request timeout in seconds.

    .PARAMETER Proxy
        The proxy server to use.

    .PARAMETER ProxyCredential
        The credential for the proxy server.

    .PARAMETER SkipCertificateCheck
        Skips the validation of the server certificate. Use only for testing.

    .PARAMETER MaxRetries
        How many times a failed request is retried.

    .PARAMETER Persist
        Saves the connection (secrets encrypted) so that later sessions load it.

    .PARAMETER PassThru
        Returns the context.

    .EXAMPLE
        Set-ReservedNamesContext -BaseUri 'https://api.example.com' -BearerToken (Read-Host -AsSecureString -Prompt 'Token')

    .LINK
        Set-OpenApiContext
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $BaseUri,

        [Parameter()]
        [System.Security.SecureString]
        $ApiKey,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [System.Security.SecureString]
        $BearerToken,

        [Parameter()]
        [string]
        $ClientId,

        [Parameter()]
        [System.Security.SecureString]
        $ClientSecret,

        [Parameter()]
        [string]
        $TokenUri,

        [Parameter()]
        [string[]]
        $Scope,

        [Parameter()]
        [hashtable]
        $Header,

        [Parameter()]
        [int]
        $TimeoutSec,

        [Parameter()]
        [string]
        $Proxy,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $ProxyCredential,

        [Parameter()]
        [switch]
        $SkipCertificateCheck,

        [Parameter()]
        [int]
        $MaxRetries,

        [Parameter()]
        [switch]
        $Persist,

        [Parameter()]
        [switch]
        $PassThru
    )

    $tcsContext = @{}
    foreach ($tcsName in @($PSBoundParameters.Keys)) {
        if (@('WhatIf', 'Confirm') -notcontains $tcsName) {
            $tcsContext[$tcsName] = $PSBoundParameters[$tcsName]
        }
    }
    $tcsContext['BaseUri'] = $BaseUri
    $tcsContext['Service'] = $script:TcsOpenApiService
    if ($PSCmdlet.ShouldProcess($script:TcsOpenApiService, 'Set the API connection')) {
        Set-OpenApiContext @tcsContext
    }
}
