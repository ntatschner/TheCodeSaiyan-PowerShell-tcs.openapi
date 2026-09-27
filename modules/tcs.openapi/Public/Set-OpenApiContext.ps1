<#
.SYNOPSIS
    Stores the connection (base URI, credentials and transport settings) for an OpenAPI service.

.DESCRIPTION
    Set-OpenApiContext saves how to reach a service in the current session: its base URI, the credentials for
    each kind of security scheme, extra headers, timeout, proxy and retry settings. Invoke-OpenApiRequest (and every
    command of a generated module) uses the context of its service. Setting a context replaces the previous one of
    the same service.

    Secrets are kept as SecureString and decoded only when a request is built. With -Persist the context is also
    saved for later sessions: secrets with tcs.core Set-ModuleSecret (module tcs.openapi, names
    '<Service>.ApiKey', '<Service>.BearerToken', '<Service>.ClientSecret', '<Service>.Credential' and
    '<Service>.ProxyCredential'), and the other settings as JSON in
    '<config root>/tcs.openapi/Contexts/<Service>.json'. A later session loads the saved context the first time
    the service is used.

.PARAMETER Service
    The service name, for example the name of a generated module. Letters, digits, '.', '_' and '-'.

.PARAMETER BaseUri
    The base URL of the API; operation paths are appended to it.

.PARAMETER ApiKey
    The key used for apiKey security schemes (in a header, query parameter or cookie, as the scheme says).

.PARAMETER Credential
    The user name and password used for HTTP basic authentication.

.PARAMETER BearerToken
    The token used for HTTP bearer authentication; it is also used for OAuth2 and OpenID Connect schemes.

.PARAMETER ClientId
    The OAuth2 client ID for the client credentials flow.

.PARAMETER ClientSecret
    The OAuth2 client secret for the client credentials flow.

.PARAMETER TokenUri
    The OAuth2 token endpoint. Defaults to the tokenUrl of the scheme's clientCredentials flow.

.PARAMETER Scope
    The OAuth2 scopes to request. Defaults to the scopes the operation's security requirement lists.

.PARAMETER Header
    Headers sent with every request, for example @{ 'X-Tenant' = 'contoso' }. Values are saved in plain text with
    -Persist, so put secrets in -ApiKey or -BearerToken instead.

.PARAMETER TimeoutSec
    The request timeout in seconds. 0 means no timeout. Defaults to 100.

.PARAMETER Proxy
    The URL of a proxy server to use.

.PARAMETER ProxyCredential
    The credential for the proxy server.

.PARAMETER SkipCertificateCheck
    Accepts any server certificate. Use only for test servers.

.PARAMETER MaxRetries
    How many times a throttled or failed request is retried. Defaults to 3.

.PARAMETER Persist
    Also saves the context (secrets encrypted with tcs.core) for later sessions.

.PARAMETER PassThru
    Returns the context, with secrets shown as ********.

.INPUTS
    None
    This function does not accept pipeline input.

.OUTPUTS
    Tcs.OpenApi.Context
    With -PassThru.

.EXAMPLE
    Set-OpenApiContext -Service 'PetStore' -BaseUri 'https://petstore.example.com/v1' -ApiKey (Read-Host -AsSecureString -Prompt 'API key')

    Connects the PetStore service with an API key for this session.

.EXAMPLE
    $secret = Read-Host -AsSecureString -Prompt 'Client secret'
    Set-OpenApiContext -Service 'Billing' -BaseUri 'https://api.example.com' -ClientId 'my-app' -ClientSecret $secret -TokenUri 'https://login.example.com/oauth2/token' -Scope 'billing.read' -Persist

    Uses OAuth2 client credentials and saves the context for later sessions.

.NOTES
    Author: Nigel Tatschner
    Company: TheCodeSaiyan

.LINK
    Get-OpenApiContext
.LINK
    Remove-OpenApiContext
.LINK
    Invoke-OpenApiRequest
#>
function Set-OpenApiContext {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType('Tcs.OpenApi.Context')]
    param(
        [Parameter(Mandatory, HelpMessage = 'The service name.')]
        [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')]
        [string]$Service,

        [Parameter(Mandatory, HelpMessage = 'The base URL of the API.')]
        [ValidateNotNullOrEmpty()]
        [uri]$BaseUri,

        [Parameter(HelpMessage = 'The key for apiKey security schemes.')]
        [System.Security.SecureString]$ApiKey,

        [Parameter(HelpMessage = 'The credential for HTTP basic authentication.')]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter(HelpMessage = 'The token for HTTP bearer authentication.')]
        [System.Security.SecureString]$BearerToken,

        [Parameter(HelpMessage = 'The OAuth2 client ID.')]
        [string]$ClientId,

        [Parameter(HelpMessage = 'The OAuth2 client secret.')]
        [System.Security.SecureString]$ClientSecret,

        [Parameter(HelpMessage = 'The OAuth2 token endpoint.')]
        [uri]$TokenUri,

        [Parameter(HelpMessage = 'The OAuth2 scopes to request.')]
        [string[]]$Scope,

        [Parameter(HelpMessage = 'Headers sent with every request.')]
        [hashtable]$Header,

        [Parameter(HelpMessage = 'The request timeout in seconds.')]
        [ValidateRange(0, 86400)]
        [int]$TimeoutSec = 100,

        [Parameter(HelpMessage = 'The URL of a proxy server.')]
        [uri]$Proxy,

        [Parameter(HelpMessage = 'The credential for the proxy server.')]
        [System.Management.Automation.PSCredential]$ProxyCredential,

        [Parameter(HelpMessage = 'Accept any server certificate.')]
        [switch]$SkipCertificateCheck,

        [Parameter(HelpMessage = 'How many times a failed request is retried.')]
        [ValidateRange(0, 100)]
        [int]$MaxRetries = 3,

        [Parameter(HelpMessage = 'Save the context for later sessions.')]
        [switch]$Persist,

        [Parameter(HelpMessage = 'Return the context.')]
        [switch]$PassThru
    )

    Invoke-TcsCommand -ScriptBlock {
        if (-not $BaseUri.IsAbsoluteUri -or ($BaseUri.Scheme -ne 'http' -and $BaseUri.Scheme -ne 'https')) {
            throw (New-Object System.ArgumentException -ArgumentList "The base URI '$BaseUri' must be an absolute http or https URL.", 'BaseUri')
        }
        if (($ClientId -or $ClientSecret) -and -not ($ClientId -and $ClientSecret)) {
            throw (New-Object System.ArgumentException -ArgumentList 'OAuth2 client credentials need both -ClientId and -ClientSecret.')
        }
        $tokenText = $null
        if ($null -ne $TokenUri) {
            $tokenText = $TokenUri.AbsoluteUri
        }
        $proxyText = $null
        if ($null -ne $Proxy) {
            $proxyText = $Proxy.AbsoluteUri
        }
        $contextParameters = @{
            Service              = $Service
            BaseUri              = $BaseUri.AbsoluteUri
            ApiKey               = $ApiKey
            Credential           = $Credential
            BearerToken          = $BearerToken
            ClientId             = $ClientId
            ClientSecret         = $ClientSecret
            TokenUri             = $tokenText
            Scope                = $Scope
            Header               = $Header
            TimeoutSec           = $TimeoutSec
            Proxy                = $proxyText
            ProxyCredential      = $ProxyCredential
            SkipCertificateCheck = [bool]$SkipCertificateCheck
            MaxRetries           = $MaxRetries
            Persisted            = [bool]$Persist
        }
        $context = New-OpenApiContext @contextParameters

        $target = "OpenAPI context '$Service' ($($context.BaseUri))"
        $action = 'Set connection'
        if ($Persist) {
            $action = 'Set and save connection'
        }
        if ($PSCmdlet.ShouldProcess($target, $action)) {
            if ($Persist) {
                Save-OpenApiContextSetting -Context $context
            }
            $store = Get-OpenApiContextStore
            $store[$Service] = $context
            Clear-OpenApiHttpClientCache -Service $Service
            Clear-OpenApiTokenCache -Service $Service
            if ($PassThru) {
                ConvertTo-OpenApiContextView -Context $context
            }
        }
    }
}
