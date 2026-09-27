<#
.SYNOPSIS
    Returns the stored connections of OpenAPI services, with every secret shown as ********.

.DESCRIPTION
    Get-OpenApiContext returns the context set with Set-OpenApiContext for one service, or for every service when
    no name is given. Contexts saved with -Persist in an earlier session are loaded too. Secrets (API key, bearer
    token, client secret, passwords and sensitive header values) are never returned; they are shown as ********.

.PARAMETER Service
    The service name. Wildcards are allowed. Without it, every context is returned.

.INPUTS
    None
    This function does not accept pipeline input.

.OUTPUTS
    Tcs.OpenApi.Context
    Service, BaseUri, ApiKey, Credential, BearerToken, ClientId, ClientSecret, TokenUri, Scope, Header,
    TimeoutSec, Proxy, ProxyCredential, SkipCertificateCheck, MaxRetries and Persisted.

.EXAMPLE
    Get-OpenApiContext -Service 'PetStore'

    Shows the connection of the PetStore service.

.EXAMPLE
    Get-OpenApiContext | Select-Object -Property Service, BaseUri, Persisted

    Lists every stored connection.

.NOTES
    Author: Nigel Tatschner
    Company: TheCodeSaiyan

.LINK
    Set-OpenApiContext
#>
function Get-OpenApiContext {
    [CmdletBinding()]
    [OutputType('Tcs.OpenApi.Context')]
    param(
        [Parameter(HelpMessage = 'The service name; wildcards are allowed.')]
        [SupportsWildcards()]
        [string]$Service
    )

    $telemetry = Start-TcsTelemetry
    $failure = $null
    $writtenErrors = New-Object -TypeName System.Collections.ArrayList
    try {
        $names = New-Object System.Collections.Generic.List[string]
        $store = Get-OpenApiContextStore
        foreach ($key in $store.Keys) {
            $names.Add($key)
        }
        $folder = Get-OpenApiContextSettingPath
        if (Test-Path -LiteralPath $folder) {
            foreach ($file in (Get-ChildItem -LiteralPath $folder -Filter '*.json' -File)) {
                if (-not $names.Contains($file.BaseName)) {
                    $names.Add($file.BaseName)
                }
            }
        }
        $pattern = '*'
        if (-not [string]::IsNullOrEmpty($Service)) {
            $pattern = $Service
        }
        $found = $false
        foreach ($name in ($names | Sort-Object)) {
            if ($name -notlike $pattern) {
                continue
            }
            $context = Resolve-OpenApiContext -Service $name
            if ($null -ne $context) {
                $found = $true
                ConvertTo-OpenApiContextView -Context $context
            }
        }
        if (-not $found -and -not [string]::IsNullOrEmpty($Service) -and -not [System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($Service)) {
            Write-Error -Message "There is no context for the '$Service' service. Set one with Set-OpenApiContext." -Category ObjectNotFound -TargetObject $Service -ErrorId 'OpenApi.ContextNotFound' -ErrorVariable +writtenErrors
        }
    }
    catch {
        $failure = $_
        throw
    }
    finally {
        # A written "not found" error also makes the run a failed one
        if ($null -eq $failure -and $writtenErrors.Count -gt 0) {
            $failure = $writtenErrors[0]
        }
        Complete-TcsTelemetry -Token $telemetry -ErrorRecord $failure
    }
}
