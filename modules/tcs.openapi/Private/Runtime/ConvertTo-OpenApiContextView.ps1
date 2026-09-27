function ConvertTo-OpenApiContextView {
    <#
    .SYNOPSIS
        Returns a copy of a context that is safe to display: every secret is shown as ********.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context
    )

    $mask = '********'
    $credentialView = $null
    if ($null -ne $Context.Credential) {
        $credentialView = "$($Context.Credential.UserName) / $mask"
    }
    $proxyCredentialView = $null
    if ($null -ne $Context.ProxyCredential) {
        $proxyCredentialView = "$($Context.ProxyCredential.UserName) / $mask"
    }
    $headerView = [ordered]@{}
    foreach ($key in $Context.Header.Keys) {
        if (Test-OpenApiSensitiveName -Name $key) {
            $headerView[$key] = $mask
        }
        else {
            $headerView[$key] = $Context.Header[$key]
        }
    }
    $apiKey = $null
    if ($null -ne $Context.ApiKey) {
        $apiKey = $mask
    }
    $bearer = $null
    if ($null -ne $Context.BearerToken) {
        $bearer = $mask
    }
    $clientSecret = $null
    if ($null -ne $Context.ClientSecret) {
        $clientSecret = $mask
    }
    return [pscustomobject]@{
        PSTypeName           = 'Tcs.OpenApi.Context'
        Service              = $Context.Service
        BaseUri              = $Context.BaseUri
        ApiKey               = $apiKey
        Credential           = $credentialView
        BearerToken          = $bearer
        ClientId             = $Context.ClientId
        ClientSecret         = $clientSecret
        TokenUri             = $Context.TokenUri
        Scope                = $Context.Scope
        Header               = $headerView
        TimeoutSec           = $Context.TimeoutSec
        Proxy                = $Context.Proxy
        ProxyCredential      = $proxyCredentialView
        SkipCertificateCheck = $Context.SkipCertificateCheck
        MaxRetries           = $Context.MaxRetries
        Persisted            = $Context.Persisted
    }
}
