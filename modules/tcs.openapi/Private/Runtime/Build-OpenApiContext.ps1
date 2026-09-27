function Build-OpenApiContext {
    <#
    .SYNOPSIS
        Creates the context object held in the module-scope store for one service.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$Service,

        [Parameter(Mandatory)]
        [string]$BaseUri,

        [Parameter()]
        [AllowNull()]
        [System.Security.SecureString]$ApiKey,

        [Parameter()]
        [AllowNull()]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter()]
        [AllowNull()]
        [System.Security.SecureString]$BearerToken,

        [Parameter()]
        [AllowNull()]
        [string]$ClientId,

        [Parameter()]
        [AllowNull()]
        [System.Security.SecureString]$ClientSecret,

        [Parameter()]
        [AllowNull()]
        [string]$TokenUri,

        [Parameter()]
        [AllowNull()]
        [string[]]$Scope,

        [Parameter()]
        [AllowNull()]
        [System.Collections.IDictionary]$Header,

        [Parameter()]
        [int]$TimeoutSec = 100,

        [Parameter()]
        [AllowNull()]
        [string]$Proxy,

        [Parameter()]
        [AllowNull()]
        [System.Management.Automation.PSCredential]$ProxyCredential,

        [Parameter()]
        [bool]$SkipCertificateCheck = $false,

        [Parameter()]
        [int]$MaxRetries = 3,

        [Parameter()]
        [bool]$Persisted = $false
    )

    $headerCopy = [ordered]@{}
    if ($null -ne $Header) {
        foreach ($key in $Header.Keys) {
            $headerCopy[[string]$key] = [string]$Header[$key]
        }
    }
    if ([string]::IsNullOrEmpty($Proxy)) {
        $Proxy = $null
    }
    if ([string]::IsNullOrEmpty($ClientId)) {
        $ClientId = $null
    }
    if ([string]::IsNullOrEmpty($TokenUri)) {
        $TokenUri = $null
    }
    return [pscustomobject]@{
        PSTypeName           = 'Tcs.OpenApi.ContextData'
        Service              = $Service
        BaseUri              = $BaseUri.TrimEnd('/')
        ApiKey               = $ApiKey
        Credential           = $Credential
        BearerToken          = $BearerToken
        ClientId             = $ClientId
        ClientSecret         = $ClientSecret
        TokenUri             = $TokenUri
        Scope                = @($Scope | Where-Object -FilterScript { -not [string]::IsNullOrEmpty($_) })
        Header               = $headerCopy
        TimeoutSec           = $TimeoutSec
        Proxy                = $Proxy
        ProxyCredential      = $ProxyCredential
        SkipCertificateCheck = $SkipCertificateCheck
        MaxRetries           = $MaxRetries
        Persisted            = $Persisted
    }
}
